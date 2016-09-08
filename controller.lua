local turbo     = require("turbo")
-- we use lustache instead of turbo's limited mustache engine
local lustache  = require("lustache")

local conf      = require("config")
local db        = require("db")
local mail      = require("mail")
local model     = require("model")


local cntrl     = class("cntrl")


-- move all model parts to model.lua
function cntrl:packages(args)
    local m = {}
    -- get packages
    local offset = (args.page - 1) * conf.pager.limit
    local pkgs = db:getPackages(args, offset)
    m.pkgs = model:packages(pkgs)
    local distinct = {
        branch = db:getDistinct("packages", "branch"),
        repo = db:getDistinct("packages", "repo"),
        arch = db:getDistinct("packages", "arch"),
        maintainer = db:getDistinct("maintainer", "name"),
    }
    -- navigation bar
    m.nav = {package="active"}
    -- create form
    m.form = model:packagesForm(args, distinct)
    -- create pager
    local qty = db:countPackages(args)
    local pager = self:createPager(qty, conf.pager.limit, args.page, conf.pager.offset)
    m.pager = model:pagerModel(args, pager)
    -- render templates
    m.header = lustache:render(self:tpl("header.tpl"), m)
    m.footer = lustache:render(self:tpl("footer.tpl"), m)
    return lustache:render(self:tpl("packages.tpl"), m)
end

function cntrl:getPackage(ops)
    return db:getPackage(ops)
end

function cntrl:package(pkg, m)
    local m = m or {}
    -- package
    pkg.size = self:humanBytes(pkg.size)
    pkg.installed_size = self:humanBytes(pkg.installed_size)
    m.pkg = model:package(pkg)
    -- depends
    local depends = db:getDepends(pkg)
    m.deps = model:packageRelations(depends)
    m.deps_qty = #depends or 0
    -- provides
    local provides = db:getProvides(pkg)
    m.reqbys = model:packageRelations(provides)
    m.reqbys_qty = #provides or 0
    -- origins
    local origins = db:getOrigins(pkg)
    m.subpkgs = model:packageRelations(origins)
    m.subpkgs_qty = #origins or 0
    -- navigation bar
    m.nav = {package="active"}
    -- templates
    m.header = lustache:render(self:tpl("header.tpl"), m)
    m.footer = lustache:render(self:tpl("footer.tpl"), m)
    return lustache:render(self:tpl("package.tpl"), m)
end


function cntrl:contents(args)
    local m = {}
    local distinct = {
        branch = db:getDistinct("packages", "branch"),
        repo = db:getDistinct("packages", "repo"),
        arch = db:getDistinct("packages", "arch"),
    }
    -- navigation menu
    m.nav = {content="active"}
    -- search form
    m.form = model:contentsForm(args, distinct)
    -- do not run any queries without any terms.
    if not (args.file == "" and args.path == "" and args.name == "") then
        -- get contents
        local offset = (args.page - 1) * conf.pager.limit
        local contents = db:getContents(args, offset)
        m.contents = model:contents(contents)
        -- pager
        local qty = db:countContents(args)
        local pager = self:createPager(qty, conf.pager.limit, args.page, conf.pager.offset)
        m.pager = model:pagerModel(args, pager)
    end
    -- render templates
    m.header = lustache:render(self:tpl("header.tpl"), m)
    m.footer = lustache:render(self:tpl("footer.tpl"), m)
    return lustache:render(self:tpl("contents.tpl"), m)
end

function cntrl:flag(pkg, m)
    if pkg and not pkg.fid then
        local m = model:flag(pkg, m)
        m.header = lustache:render(self:tpl("header.tpl"), m)
        m.footer = lustache:render(self:tpl("footer.tpl"), m)
        return lustache:render(self:tpl("flag.tpl"), m)
    end
end

function cntrl:flagMail(args, pkg)
    local subject = string.format(
        "Alpine aport %s has been flagged out of date",
        pkg.origin
    )
    local m = model:flagMail(pkg, args)
    mail:initialize(conf)
    mail:set_to(pkg.memail)
    mail:set_subject(subject)
    local body = lustache:render(self:tpl("mail_body.tpl"), m)
    mail:set_body(body)
    return mail:send()
end

function cntrl:flagged(args)
    local m = {}
    -- get packages
    local offset = (args.page - 1) * conf.pager.limit
    local pkgs = db:getFlagged(args, offset)
    m.pkgs = model:flagged(pkgs)
    local distinct = {
        branch = db:getDistinct("packages", "branch"),
        repo = db:getDistinct("packages", "repo"),
        arch = db:getDistinct("packages", "arch"),
        maintainer   = db:getDistinct("maintainer", "name"),
    }
    -- create form
    m.form = model:flaggedForm(args, distinct)
    -- navigation menu
    m.nav = {flagged="active"}
    -- create pager
    local qty = db:countFlagged(args)
    local pager = self:createPager(qty, conf.pager.limit, args.page, conf.pager.offset)
    m.pager = model:pagerModel(args, pager)
    -- render templates
    m.header = lustache:render(self:tpl("header.tpl"), m)
    m.footer = lustache:render(self:tpl("footer.tpl"), m)
    return lustache:render(self:tpl("flagged.tpl"), m)
end

----
-- get non flagged package based on options
----
function cntrl:getNotFlagged(ops)
    local pkg = db:getPackage(ops)
    if pkg and not pkg.fid then
        return pkg
    end
end

-- create a array with pager page numbers
-- (total) total amount of results
-- (limit) results per page/query
-- (current) the current page
-- (offset) the left and right offset from current page
function cntrl:createPager(total, limit, current, offset)
    local r = {}
    local pages = math.ceil(total/limit)
    local pagers = math.min(offset*2+1, pages)
    local first = math.max(1, current - offset)
    local last = math.min(pages, (pagers + first - 1))
    local size = (last-first+1)
    if size < pagers then
        first = first - (pagers - size)
    end
    for p = first, last do
        table.insert(r, p)
    end
    r.last = pages
    return r
end

----
-- verify recaptch responce
----
function cntrl:verifyRecaptcha(response)
    local uri = "https://www.google.com/recaptcha/api/siteverify"
    local kwargs = {}
    kwargs.method = "POST"
    kwargs.params = {
        secret = conf.rc.secret,
        response = response
    }
    local res = coroutine.yield(turbo.async.HTTPClient():fetch(uri, kwargs))
    if res.error then
        return false
    end
    local result = turbo.escape.json_decode(res.body)
    return result.success
end

-- convert bytes to human readable
function cntrl:humanBytes(bytes)
    local mult = 10^(2)
    local size = { 'B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB' }
    local factor = math.floor((string.len(bytes) -1) /3)
    local result = bytes/math.pow(1024, factor)
    return math.floor(result * mult + 0.5) / mult.." "..size[factor+1]
end

-- read the tpl file into a string and return it
function cntrl:tpl(tpl)
    local tpl = string.format("%s/%s", conf.tpl, tpl)
    local f = io.open(tpl, "rb")
    local r = f:read("*all")
    f:close()
    return r
end

----
-- clear reverse proxy cache
----
function cntrl:clearCache()
    if conf.cache.clear then
        local p = io.popen(string.format("find '%s' -type f -maxdepth '%s'",
            conf.cache.path, conf.cache.depth))
        for file in p:lines() do
            -- hardcode mandatory base directory
            if file:match("cache") then
                os.remove(file)
            end
        end
    end
end

return cntrl
