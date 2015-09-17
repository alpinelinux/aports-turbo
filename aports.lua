#!/usr/bin/env luajit

-- include config file
conf = dofile("conf.lua")

-- lua turbo application
TURBO_SSL = true
turbo = require "turbo"

local smtp = require("socket.smtp")
-- we use lustache instead of turbo's limited mustache engine
local lustache = require("lustache")

local db = require("db")
local apkindex = db.apkindex()
local filelist = db.filelist()
local flagged = db.flagged()

local mail = require("mail")

--
-- usefule lua helper functions
--

-- check if string begins with prefix
function string.begins(str, prefix)
    return str:sub(1,#prefix)==prefix
end

-- urlencode a string
function urlencode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w ])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
    end
    return str
end

-- convert bytes to human readable
function human_bytes(bytes)
    local mult = 10^(2)
    local size = { 'B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB' }
    local factor = math.floor((string.len(bytes) -1) /3)
    local result = bytes/math.pow(1024, factor)
    return math.floor(result * mult + 0.5) / mult.." "..size[factor+1]
end

-- return a filtered valid email address or nil
function validate_email(addr)
    return addr:match("[A-Za-z0-9%.%%%+%-]+@[A-Za-z0-9%.%%%+%-]+%.%w%w%w?%w?")
end

function parse_rfc822(addr)
    local r = {}
    if is_set(addr) then
        local name, email = turbo.escape.trim(addr):match("(.*)(<.*>)")
        if is_set(email) then r.email = validate_email(email) end
        if is_set(name) then r.name = turbo.escape.trim(name) end
    end
    if r.email or r.name then return r end
end

function format_maintainer(maintainer)
    local addr = parse_rfc822(maintainer)
    if addr and addr.name then
        return addr.name
    else
        return "None"
    end
end

function is_set(str)
   if str and str ~= "" then return str end
end

-- read the tpl file into a string and return it
function tpl(tpl)
    local f = io.open(conf.tpl.."/"..tpl, "rb")
    local r = f:read("*all")
    f:close()
    return r
end

function create_db()
    apkindex:create()
    filelist:create()
end

-- format a date
function format_date(ts)
    return os.date('%Y-%m-%d %H:%M:%S', ts)
end

--
-- Provide alert messages to mustache
--
local Alert = class("Alert")

function Alert:initialize()
    self.alert = false
end

function Alert:set_msg(msg, type)
    self.alert = {{msg=msg,type=type}}
end

function Alert:get_msg()
    local r = self.alert
    self.alert = false
    return r
end

--
-- misc functions
--

-- check if version exist in apkindex
function OriginExists(repo, origin, version)
    local origins = apkindex:get_origin(repo, origin)
    if (type(origins) == "table") then
        for _,f in pairs (origins) do
            if f.version == version then
                return true
            end
        end
    end
end

-- send the responce back to google to verify the captcha
function RecaptchaVerify(response)
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

-- simple helper to filter our deps in case we find multiple dep packages
-- in multiple repositories, deps in its own repo are always prefered
function FilterDeps(deps, repo)
    for k,v in pairs(deps) do
        if (v.repo == repo) then
            return v
        end
    end
    return deps[1]
end

-- create a array with pager page numbers
-- append is last page in the pager
function CreatePager(total, limit, current, offset)
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

--
-- Model section
--

function PagerModel(args, total)
    local result = {}
    local pager = CreatePager(total, conf.pager.limit, args.page, conf.pager.offset)
    if pager.last > conf.pager.offset then
        table.insert(pager, 1, "&laquo;")
        table.insert(pager, "&raquo;")
        for k,p in ipairs(pager) do
            local r = {}
            for g,v in pairs(args) do
                if (g=="page") then
                    if p == "&laquo;" then
                        v=1
                    elseif p == "&raquo;" then
                        v=pager.last
                    else
                        v=p
                    end
                end
                r[#r+1]=string.format("%s=%s", urlencode(g), urlencode(v))
            end
            path=table.concat(r, '&amp;')
            class = (args.page == p) and "active" or ""
            table.insert(result, {args=path, class=class, page=p})
        end
    end
    return result
end

-- get pkgname with same origin
function SubPackagesModel(pkg)
    local r = {}
    local origins = apkindex:get_origin(pkg.repo, pkg.origin, pkg.arch)
    for k,v in pairs (origins) do
        if v.name ~= pkg.name then
            r[#r+1] = {
                path=string.format("/package/%s/%s/%s", v.repo, v.arch, v.name),
                text=v.name
            }
        end
    end
    return r
end

function DependsModel(pkg)
    local r,d,sd,rd = {},{},{},{}
    for k,v in pairs (pkg.depends:split(" ")) do
        -- resolve so deps
        if v:begins('so:') then
            sdpkg = apkindex:get_depends("%"..v.."%", "%", pkg.arch)
            if next(sdpkg) then
                sd = FilterDeps(sdpkg, pkg.repo)
                r[sd.name] = sd
            end
        else
            local name = v:gsub('=.*', '')
            dpkg = apkindex:get_depends("%", name, pkg.arch)
            if next(dpkg) then
                d = FilterDeps(dpkg, pkg.repo)
                r[d.name] = d
            end
        end
    end
    for name,p in pairs(r) do
        rd[#rd+1] = {
            path=string.format("/package/%s/%s/%s", p.repo, p.arch, p.name),
            text=p.name
        }
    end
    return rd
end

function RequiredByModel(pkg)
    local pkgs,r,rb = {},{},{}
    local deps = pkg.provides:split(" ")
    for _,d in pairs(deps) do
        -- remove version data
        -- we do not support verioned deps
        d = d:gsub('=.*', '')
        pkgs = apkindex:get_required_by("%"..d.."%", pkg.arch)
        for k,v in pairs(pkgs) do
            r[v.name..v.repo] = v
        end
    end
    -- lookup package that depends on pkgname
    pkgs = apkindex:get_required_by("%"..pkg.name.."%", pkg.arch)
    for k,v in pairs(pkgs) do
        if turbo.util.is_in(pkg.name, v.depends:split(" ")) then
            r[v.name..v.repo] = v
        end
    end
    -- format the model
    for _,p in pairs(r) do
        rb[#rb+1] = {
            path=string.format("/package/%s/%s/%s", p.repo, p.arch, p.name),
            text=p.name
        }
    end
    return rb
end

function PackageModel(pkg)
    local flag = flagged:get_status(pkg.origin, pkg.repo, pkg.version)
    if flag then
        pkg.version = {
            class="text-danger",
            text=pkg.version,
            title=string.format("Flagged: %s", format_date(flag.date)),
            path="#"
        }
    else
        pkg.version = {
            class="text-success",
            text=pkg.version,
            title=string.format("Flag this package out of date"),
            path=string.format("/flag/%s/%s/%s", pkg.repo, pkg.origin, pkg.version),
        }
    end
    return {
        name = is_set(pkg.name) or "None",
        version = is_set(pkg.version) or "None",
        description = is_set(pkg.description) or "None",
        url = is_set(pkg.url) or "None",
        license = is_set(pkg.license) or "None",
        repo = is_set(pkg.repo) or "None",
        arch = is_set(pkg.arch) or "None",
        size = pkg.size and human_bytes(pkg.size) or "None",
        installed_size = is_set(pkg.installed_size) and human_bytes(pkg.installed_size) or "None",
        origin = is_set(pkg.origin) and {
            path=string.format("/package/%s/%s/%s", pkg.repo, pkg.arch, pkg.origin),
            text=pkg.origin
        } or {path="#", text="None"},
        maintainer = is_set(format_maintainer(pkg.maintainer)) or "None",
        build_time = is_set(pkg.build_time) and format_date(pkg.build_time) or "None",
        commit = is_set(pkg.commit) and {
            path=string.format("http://git.alpinelinux.org/cgit/aports/commit/?id=%s", pkg.commit),
            text=pkg.commit
        } or {path="#", text="None"},
        contents = {
            path=string.format("/contents?pkgname=%s&arch=%s&repo=%s", pkg.name, pkg.arch, pkg.repo),
            text="Contents of package"
        },
    }
end

function PackagesModel(pkgs)
    local r = {}
    for k,v in pairs(pkgs) do
        r[k] = {}
        r[k].name = {
            path=string.format("/package/%s/%s/%s", v.repo, v.arch, v.name),
            text=v.name,
            title=v.description
        }
        r[k].version = {
            path=string.format("/flag/%s/%s/%s", v.repo, v.origin, v.version),
            text=v.version,
            title="Flag this package out of date"
        }
        r[k].url = {
            path=v.url,
            text="URL",
            title=v.url
        }
        r[k].license = v.license
        r[k].arch = v.arch
        r[k].repo = v.repo
        r[k].maintainer = format_maintainer(v.maintainer)
        r[k].build_time = format_date(v.build_time)
        local fs = flagged:get_status(v.origin, v.repo, v.version)
        if (fs) then r[k].flagged = {date=format_date(fs.date)} end
    end
    return r
end

function ContentsModel(contents)
    local r = {}
    for k,v in pairs(contents) do
        r[k] = {}
        r[k].file = string.format("/%s/%s", v.path, v.file)
        r[k].pkgname = {
            path = string.format("/package/%s/%s/%s", v.repo, v.arch, v.pkgname),
            text = v.pkgname,
        }
        r[k].repo = v.repo
        r[k].arch = v.arch
    end
    return r
end

function FormArchModel(selected)
    local r = {}
    local archs = apkindex:get_distinct("arch")
    table.insert(archs, {arch="all"})
    for k,v in pairs(archs) do
        r[k] = {text=v.arch}
        if (v.arch == selected) then
            r[k].selected = "selected"
        end
    end
    return r
end

function FormRepoModel(selected)
    local r = {}
    local repos = apkindex:get_distinct("repo")
    table.insert(repos, {repo="all"})
    for k,v in pairs(repos) do
        r[k] = {text=v.repo}
        if (v.repo == selected) then
            r[k].selected = "selected"
        end
    end
    return r
end

function FormMaintainerModel(selected)
    local r = {}
    -- create a list of maintainers by name and filter dups
    local maintainers = apkindex:get_distinct("maintainer")
    for k,v in ipairs(maintainers) do
        local m = parse_rfc822(v.maintainer)
        if m and is_set(m.name) then
            r[m.name] = m.name
        end
    end
    -- sort the table
    local s = {}
    for k,v in pairs(r) do
        table.insert(s,v)
    end
    table.sort(s)
    -- create the model
    local t = {{value="all", text="all"}}
    if selected == "all" then t[#t].selected = "selected" end
    for k,v in ipairs(s) do
        t[#t+1] = {value=v,text=limit_string(v, 25)}
        if v == selected then t[#t].selected = "selected" end
    end
    return t
end

function limit_string(str, len)
    if string.len(str) > len then
        return string.sub(str,1,len).."..."
    end
    return str
end

function PackagesFormModel(name, repo, arch, maintainer)
    local r = {}
    r.repo = FormRepoModel(repo)
    r.arch = FormArchModel(arch)
    r.maintainer = FormMaintainerModel(maintainer)
    r.name = name
    return r
end

function ContentsFormModel(file, path, pkgname, repo, arch)
    return {
        repo = FormRepoModel(repo),
        arch = FormArchModel(arch),
        filename = file,
        path = path,
        name = pkgname,
    }
end

function FlagModel(pkg)
    return {
        repo = pkg.repo,
        origin = pkg.origin,
        version = pkg.version,
        maintainer = format_maintainer(pkg.maintainer),
        sitekey = conf.rc.sitekey
    }
end

function FlaggedModel(pkgs, arch)
    local r = {}
    for k,v in ipairs(pkgs) do
        r[k] = {}
        r[k].origin = {
            text = v.origin,
            path = string.format("/packages?name=%s&arch=%s", v.origin, arch),
            title = "",
        }
        r[k].repo = v.repo
        r[k].version = v.version
        r[k].date = format_date(v.date)
        r[k].message = v.message
    end
    return r
end

function MailMaintainerModel(pkg, from, message)
    return {
        maintainer =  format_maintainer(pkg.maintainer),
        origin = pkg.origin,
        from = from,
        message = message
    }
end
--
-- Turbo request handlers
--

-- contentets renderer to display package contents
local ContentsRenderer = class("ContentsRenderer", turbo.web.RequestHandler)

function ContentsRenderer:get()
    local m = {}
    local a = {
        filename = self:get_argument("filename", "", true),
        path = self:get_argument("path", "", true),
        pkgname = self:get_argument("pkgname", "", true),
        arch = self:get_argument("arch", "x86_64", true),
        repo = self:get_argument("repo", "all", true),
        page = tonumber(self:get_argument("page", 1, true))
    }
    m.nav = {package="", content="active"}
    m.alert = self.options.alert:get_msg()
    m.form = ContentsFormModel(a.filename, a.path, a.pkgname, a.repo, a.arch)
    if not (a.filename == "" and a.path == ""  and a.pkgname == "") then
        local contents = filelist:get_files(a.filename, a.path, a.pkgname, a.arch, a.repo, a.page)
        local count = filelist:count_files(a.filename, a.path, a.pkgname, a.arch, a.repo)
        m.contents = ContentsModel(contents)
        m.pager = PagerModel(a, count)
    end
    m.header = lustache:render(tpl("header.tpl"), m)
    m.footer = lustache:render(tpl("footer.tpl"), m)
    self:write(lustache:render(tpl("contents.tpl"), m))
end

-- packages renderer to display a list of packages
local PackagesRenderer = class("PackagesRenderer", turbo.web.RequestHandler)

function PackagesRenderer:get()
    local m = {}
    local a = {
        name = self:get_argument("name","", true),
        arch = self:get_argument("arch", "x86_64", true),
        repo = self:get_argument("repo", "all", true),
        maintainer = self:get_argument("maintainer", "all", true),
        page = tonumber(self:get_argument("page", 1, true)),
    }
    local pkgs = apkindex:get_packages(a.name, a.repo, a.arch, a.maintainer, a.page)
    local num = apkindex:count_packages(a.name, a.repo, a.arch, a.maintainer)
    m.nav = {package="active", content=""}
    m.alert = self.options.alert:get_msg()
    m.form = PackagesFormModel(a.name, a.repo, a.arch, a.maintainer)
    m.pkgs = PackagesModel(pkgs)
    m.pager = PagerModel(a, num)
    m.header = lustache:render(tpl("header.tpl"), m)
    m.footer = lustache:render(tpl("footer.tpl"), m)
    self:write(lustache:render(tpl("packages.tpl"), m))
end

-- package renderer, to display a single package
local PackageRenderer = class("PackageRenderer", turbo.web.RequestHandler)

function PackageRenderer:get(repo, arch, name)
    local m = {}
    local ops = {repo=repo, arch=arch, name=name}
    local pkg = apkindex:get_package(ops)
    if not pkg then
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
    m.nav = {package="active", content=""}
    m.alert = self.options.alert:get_msg()
    m.pkg = PackageModel(pkg)
    m.deps = DependsModel(pkg)
    m.deps_qty = (m.deps ~= nil) and #m.deps or "0"
    m.subpkgs = SubPackagesModel(pkg)
    m.subpkgs_qty = (m.subpkgs) and #m.subpkgs or "0"
    m.reqbys = RequiredByModel(pkg)
    m.reqbys_qty = (m.reqbys ~= nil) and #m.reqbys or "0"
    m.header = lustache:render(tpl("header.tpl"), m)
    m.footer = lustache:render(tpl("footer.tpl"), m)
    self:write(lustache:render(tpl("package.tpl"), m))
end

-- flagged renderer, to display the flag form
local FlagRenderer = class("FlagRenderer", turbo.web.RequestHandler)

function FlagRenderer:get(repo, origin, version)
    local args = {"flag",repo,origin,version}
    local ops = {origin=origin, repo=repo}
    local pkg = apkindex:get_package(ops)
    --trow an http error if this package doesnt exists
    if not OriginExists(repo, origin, version) then
        error(turbo.web.HTTPError(404, "404 Page not found."))
    -- display alert when origin is already flagged
    elseif flagged:get_status(origin, repo, version) then
        alert = "This origin has already been flagged"
        self.options.alert:set_msg(alert, "danger")
    end
    local m = FlagModel(pkg)
    m.alert = self.options.alert:get_msg()
    m.header = lustache:render(tpl("header.tpl"), m)
    m.footer = lustache:render(tpl("footer.tpl"), m)
    self:write(lustache:render(tpl("flag.tpl"), m))
end

-- flagged post function when submitting the form
function FlagRenderer:post(repo, origin, version)
    local alert = "Sucessfully flagged packages"
    local type  = "danger"
    local args = {"flag",repo,origin,version}
    local message = self:get_argument("message", false)
    local from = self:get_argument("from", "")
    local responce = self:get_argument("g-recaptcha-response", "")
    --- lets do some checks if this is a proper post
    --trow an http error if this package doesnt exists
    if not OriginExists(repo, origin, version) then
        error(turbo.web.HTTPError(404, "404 Page not found."))
    -- display alert when origin is already flagged
    elseif flagged:get_status(origin, repo, version) then
        alert = "This origin has already been flagged"
    -- check for valid email address
    elseif not validate_email(from) then
        alert = "Please provide a valid email address."
    -- verify captha if enabled
    elseif conf.rc.sitekey and not RecaptchaVerify(responce) then
        alert = "Failed to pass recaptcha. Please try again."
    -- flag origin, if failed we display an alert
    elseif not flagged:flag_origin(repo, origin, version, message) then
        alert = [[ Failed to flag origin package: origin ]]
    -- all is well (we presume)
    else
        args = {"packages"}
        type = "success"
        local ops = {origin=origin, repo=repo}
        local pkg = apkindex:get_package(ops)
        -- Check if we have a valid maintainer recipient
        if validate_email(pkg.maintainer) then
            local subject = string.format("Alpine aport %s has been flagged out of date", origin)
            mail:set_from(conf.mail.from)
            mail:set_rcpt(pkg.maintainer)
            mail:set_to(pkg.maintainer)
            mail:set_subject(subject)
            local model = MailMaintainerModel(pkg, from, message)
            body = lustache:render(tpl("mail_body.tpl"), model)
            mail:set_body(body)
            local result = mail:send()
            if not result then
                alert = "Succesfully notified maintainer"
                type = "success"
            end
        end
    end
    -- set the alert and redirect
    self.options.alert:set_msg(alert, type)
    self:redirect("/"..table.concat(args, "/"), true)
end

-- flagged renderer, to display the flag form
local FlaggedRenderer = class("FlaggedRenderer", turbo.web.RequestHandler)

function FlaggedRenderer:get()
    local m = {}
    local name = self:get_argument("name","", true)
    local arch = self:get_argument("arch", "x86_64", true)
    local repo = self:get_argument("repo", "all", true)
    local page = tonumber(self:get_argument("page", 1, true))
    m.form = PackagesFormModel(name, repo, arch)
    local ops = {origin=name,repo=repo}
    local pkgs = flagged:get_flagged(ops)
    m.pkgs = FlaggedModel(pkgs, arch)
    m.header = lustache:render(tpl("header.tpl"), m)
    m.footer = lustache:render(tpl("footer.tpl"), m)
    self:write(lustache:render(tpl("flagged.tpl"), m))
end

function main()
    local alert = Alert()
    turbo.web.Application({
        {"^/$", turbo.web.RedirectHandler, "/packages"},
        {"^/contents$", ContentsRenderer, {alert=alert}},
        {"^/packages$", PackagesRenderer, {alert=alert}},
        {"^/package/(.*)/(.*)/(.*)$", PackageRenderer, {alert=alert}},
        {"^/flag/(.*)/(.*)/(.*)$", FlagRenderer, {alert=alert}},
        {"^/flagged$", FlaggedRenderer, {alert=alert}},
        {"^/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
        {"^/robots.txt", turbo.web.StaticFileHandler, "assets/robots.txt"},
    }):listen(conf.port)
    local loop = turbo.ioloop.instance()
    loop:set_interval(60000 * conf.update, create_db)
    loop:start()
end

create_db()
main()
