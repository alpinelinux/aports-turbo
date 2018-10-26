local turbo     = require("turbo")
-- we use lustache instead of turbo's limited mustache engine
local lustache  = require("lustache")

local conf      = require("config")
local db        = require("db")
local mail      = require("mail")
local model     = require("model")

local cntrl     = {}

db:open()

-- convert bytes to human readable
local function humanBytes(bytes)
    local mult = 10^(2)
    local size = { 'B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB' }
    local factor = math.floor((string.len(bytes) -1) /3)
    local result = bytes/math.pow(1024, factor)
    return math.floor(result * mult + 0.5) / mult.." "..size[factor+1]
end

-- open the tpl file into a string and return it
local function open_tpl(tpl)
    local file = ("%s/%s"):format(conf.tpl, tpl)
    local f = io.open(file, "rb")
    local r = f:read("*all")
    f:close()
    return r
end

function cntrl.packages(args)
    db:select(args.branch)
    local m = {}
    -- get packages
    local offset = (args.page - 1) * conf.pager.limit
    local pkgs = db:getPackages(args, offset)
    m.pkgs = model.packages(pkgs, args.branch)
    local distinct = {
        branch = conf.branches,
        repo = conf.repos,
        arch = conf.archs,
        maintainer = db:getDistinct("maintainer", "name"),
    }
    table.insert(distinct.maintainer, 1, "None")
    -- navigation bar
    m.nav = {package="active"}
    -- create form
    m.form = model.packagesForm(args, distinct)
    -- create pager
    local qty = db:countPackages(args)
    local pager = cntrl.createPager(qty, conf.pager.limit, args.page, conf.pager.offset)
    m.pager = model.pagerModel(args, pager)
    -- render templates
    m.header = lustache:render(open_tpl("header.tpl"), m)
    m.footer = lustache:render(open_tpl("footer.tpl"), m)
    return lustache:render(open_tpl("packages.tpl"), m)
end

function cntrl.getPackage(branch, repo, arch, name)
    db:select(branch)
    return db:getPackage(branch, repo, arch, name)
end

function cntrl.package(pkg, m)
    db:select(pkg.branch)
    m = m or {}
    -- package
    pkg.size = humanBytes(pkg.size)
    pkg.installed_size = humanBytes(pkg.installed_size)
    m.pkg = model.package(pkg)
    -- depends
    local depends = db:getDepends(pkg)
    m.deps = model.packageRelations(depends)
    m.deps_qty = #depends or 0
    -- provides
    local provides = db:getProvides(pkg)
    m.reqbys = model.packageRelations(provides)
    m.reqbys_qty = #provides or 0
    -- origins
    local origins = db:getOrigins(pkg)
    m.subpkgs = model.packageRelations(origins)
    m.subpkgs_qty = #origins or 0
    -- navigation bar
    m.nav = {package="active"}
    -- templates
    m.header = lustache:render(open_tpl("header.tpl"), m)
    m.footer = lustache:render(open_tpl("footer.tpl"), m)
    return lustache:render(open_tpl("package.tpl"), m)
end


function cntrl.contents(args)
    db:select(args.branch)
    local m = {}
    -- navigation menu
    m.nav = {content="active"}
    -- search form
    m.form = model.contentsForm(args)
    -- do not run any queries without any terms.
    if not (args.file == "" and args.path == "" and args.name == "") then
        -- get contents
        local offset = (args.page - 1) * conf.pager.limit
        local contents = db:getContents(args, offset)
        m.contents = model.contents(contents, args.branch)
        -- pager
        local qty = db:countContents(args)
        local pager = cntrl.createPager(qty, conf.pager.limit, args.page, conf.pager.offset)
        m.pager = model.pagerModel(args, pager)
    end
    -- render templates
    m.header = lustache:render(open_tpl("header.tpl"), m)
    m.footer = lustache:render(open_tpl("footer.tpl"), m)
    return lustache:render(open_tpl("contents.tpl"), m)
end

function cntrl.flag(pkg, m)
    m = model.flag(pkg, m)
    m.header = lustache:render(open_tpl("header.tpl"), m)
    m.footer = lustache:render(open_tpl("footer.tpl"), m)
    return lustache:render(open_tpl("flag.tpl"), m)
end

function cntrl.flagMail(args, pkg)
    if conf.mail.enable == true then
        local subject = string.format(
            "Alpine aport %s has been flagged out of date",
            pkg.origin
        )
        local m = model.flagMail(pkg, args)
        mail:initialize(conf)
        mail:set_to(pkg.memail)
        mail:set_subject(subject)
        local body = lustache:render(open_tpl("mail_body.tpl"), m)
        mail:set_body(body)
        return mail:send()
    else
        turbo.log.warning("Mail notifications are disabled.")
        return true
    end
end

function cntrl.flagged(args, m)
    db:select(conf.default.branch)
    m = m or {}
    -- get packages
    local offset = (args.page - 1) * conf.pager.limit
    local pkgs, qty = db:getFlagged(args, offset)
    m.pkgs = model.flagged(pkgs)
    local maintainers = db:getDistinct("maintainer", "name")
    table.insert(maintainers, 1, "None")
    -- create form
    m.form = model.flaggedForm(args, maintainers)
    -- navigation menu
    m.nav = {flagged="active"}
    -- create pager
    local pager = cntrl.createPager(qty, conf.pager.limit, args.page, conf.pager.offset)
    m.pager = model.pagerModel(args, pager)
    -- render templates
    m.header = lustache:render(open_tpl("header.tpl"), m)
    m.footer = lustache:render(open_tpl("footer.tpl"), m)
    return lustache:render(open_tpl("flagged.tpl"), m)
end

function cntrl.isFlagged(origin, repo, version)
    db:select(conf.default.branch)
    return db:isFlagged(origin, repo, version)
end

function cntrl.isOrigin(branch, repo, origin, version)
    db:select(branch)
    return db:isOrigin(repo, origin, version)
end

function cntrl.getMaintainer(branch, origin)
    db:select(branch)
    return db:getMaintainer(origin)
end

function cntrl.flagOrigin(args, pkg)
    return db:flagOrigin(args, pkg)
end

-- create a array with pager page numbers
-- (total) total amount of results
-- (limit) results per page/query
-- (current) the current page
-- (offset) the left and right offset from current page
function cntrl.createPager(total, limit, current, offset)
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
-- verify recaptcha response
----
function cntrl.verifyRecaptcha(response)
    if conf.rc.sitekey == "" then
        turbo.log.warning("reCAPTCHA site key not found.")
        return true
    end
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

function cntrl.cleanup()
    db:close()
end

return cntrl
