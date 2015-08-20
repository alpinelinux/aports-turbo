#!/usr/bin/env luajit

-- include config file
local conf = dofile("conf.lua")

-- lua turbo application
TURBO_SSL = true
local turbo = require "turbo"
local dbi = require "DBI"
local smtp = require("socket.smtp")
-- we use lustache instead of turbo's limited mustache engine
local lustache = require("lustache")

--
-- open databases. these will be overwritten by our aports scripts.
-- flagged is persistent and should not be monitored by turbovisor.
---
local apkindex = assert(dbi.DBI.Connect('SQLite3', 'db/apkindex.db'))
local filelist = assert(dbi.DBI.Connect('SQLite3', 'db/filelist.db'))
local flagged  = assert(dbi.DBI.Connect('SQLite3', 'db/persistent/flagged.db'))

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

-- Return a valid email address if found, or none when not found
function format_maintainer(maintainer)
    return validate_email(maintainer) and
            string.gsub(maintainer, ' <.*>', '') or "None"
end

-- read the tpl file into a string and return it
function tpl(tpl)
    local f = io.open(conf.tpl.."/"..tpl, "rb")
    local r = f:read("*all")
    f:close()
    return r
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
-- SendMail class using lua socket
--
local SendMail = class("SendMail")

function SendMail:initialize()
    self.rcpt = {}
    self.from = ""
    self.headers =  { ["content-type"] = "text/plain; charset=UTF-8" }
    self.body = ""
end
--add an address to the reciepient table
function SendMail:set_rcpt(rcpt)
    local addr = validate_email(rcpt)
    if addr then
        table.insert(self.rcpt, "<"..addr..">")
    end
end
-- set the from address
function SendMail:set_from(from)
    local addr = validate_email(from)
    if addr then
        self.from = "<"..addr..">"
        self.headers.from = from
    end
end
-- set the to address
function SendMail:set_to(to)
    if validate_email(to) then
        self.headers.to = to
    end
end
-- set the cc address
function SendMail:set_cc(cc)
    if validate_email(cc) then
        self.headers.cc = cc
    end
end
-- set the subject
function SendMail:set_subject(subject)
    if (type(subject) == "string") then
        self.headers.subject = subject
    end
end
-- set the body
function SendMail:set_body(body)
    self.body = body
end
-- send the email, and if failed return the error msg
function SendMail:send()
    r, e = smtp.send{
        from = self.from,
        rcpt = self.rcpt,
        source = smtp.message({
            headers = self.headers,
            body = self.body
        }),
        server = conf.mail.server,
        domain = conf.mail.domain
    }
    if not r then
        return e
    end
end

--
-- misc functions
--

-- check if version exist in apkindex
function OriginExists(repo, origin, version)
    local origins = QueryOrigin(repo, origin)
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

-- SQlite section
--

-- get the flagged data for specific origin in repo and specified version
function QueryFlaggedStatus(origin, repo, version)
    local sql = [[ select *, date(date, 'unixepoch') as date from flagged
        where origin like ? and repo like ? and version like ? ]]
    local sth = assert(flagged:prepare(sql))
    sth:execute(origin, repo, version)
    local r = sth:fetch(true)
    sth:close()
    return r
end

-- get all packages whith deps and arch
function QueryRequiredBy(dep, arch)
    local r = {}
    local sql = [[ select * from apkindex where deps like ?
        and arch like ? ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute(dep, arch)
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    return r
end

-- load a package. If arch is false we load the fist matching package
-- to fetch fields shared by each arch
function QueryPackage(name, repo, arch)
    local sql,sth,r
    arch = (arch) and arch or "%"
    sql = [[ select *, datetime(build_time, 'unixepoch') as build_time
        from apkindex where name like ? and repo like ? and arch like ? limit 1 ]]
    sth = assert(apkindex:prepare(sql))
    sth:execute(name, repo, arch)
    r = sth:fetch(true)
    sth:close()
    return r
end

-- get all packages which have certain provides
function QueryDepends(provides, name, arch)
    local r = {}
    local sql = [[ select * from apkindex where provides like ? and name like ?
        and arch like ? ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute(provides, name, arch)
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    return r
end

-- get the file list from database for a specific package
function QueryContents(filename, path, pkgname, arch, repo, page)
    local r = {}
    local sql = [[ select * from filelist where file like ? and path like ?
        and pkgname like ? and arch like ? and repo like ? limit ?,50 ]]
    local sth = assert(filelist:prepare(sql))
    local filename = (filename == "") and "%" or filename
    local path = (path == "") and "%" or path
    local pkgname = (pkgname == "") and "%" or pkgname
    repo = (repo == "all") and "%" or repo
    sth:execute(filename, path, pkgname, arch, repo, (page - 1) * 50)
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    sth:close()
    return r
end

-- count entries found by our contents query
function GetContentsCount(filename, path, pkgname, arch, repo)
    local sql = [[ select count(*) as qty from filelist where file like ?
        and path like ? and pkgname like ? and arch like ? and repo like ? ]]
    local sth = assert(filelist:prepare(sql))
    local filename = (filename == "") and "%" or filename
    local path = (path == "") and "%" or path
    local pkgname = (pkgname == "") and "%" or pkgname
    local repo = (repo == "all") and "%" or repo
    sth:execute(filename, path, pkgname, arch, repo)
    r = sth:fetch(true)
    sth:close()
    return r.qty
end

-- get a list of packages
function QueryPackages(name, repo, arch, page)
    local r = {}
    if (name=="") then name="%" end
    if (repo=="all") then repo="%" end
    local sql = [[ select * from apkindex where name like ? and repo like ?
        and arch like ? ORDER BY build_time DESC limit ?,50 ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute(name, repo, arch, (page - 1) * 50)
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    sth:close()
    return r
end

-- count query to help our pager
function GetPackagesCount(name, repo, arch)
    local sql = [[ select count(*) as qty from apkindex where name like ?
        and repo like ? and arch like ? ]]
    local sth = assert(apkindex:prepare(sql))
    repo = (repo=="all") and "%" or repo
    name = (name=="") and "%" or name
    sth:execute(name, repo, arch)
    r = sth:fetch(true)
    sth:close()
    return r.qty
end

-- add an origin entry to the flagged db
function FlagOrigin(repo, origin, version, message)
    local sql = [[ insert into flagged(repo, origin, version, date, message)
        values(?, ?, ?, strftime('%s', 'now'), ?) ]]
    local sth = assert(flagged:prepare(sql))
    sth:execute(repo, origin, version, message)
    sth:close()
    local r = flagged:commit()
    return r
end

-- get all packages with same origin in the same repo
-- with (optional) arch
function QueryOrigin(repo, origin, arch)
    local r = {}
    arch = (arch) and arch or "%"
    local sql = [[ select * from apkindex where repo like ? and origin like ?
        and arch like ? ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute(repo, origin, arch)
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    sth:close()
    return r
end

-- get unique archs
function QueryArchs()
    local r = {}
    local sql = [[ select distinct arch from apkindex ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute()
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    sth:close()
    return r
end

-- get unique repos
function QueryRepos()
    local r = {}
    local sql = [[ select distinct repo from apkindex ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute()
    for row in sth:rows(true) do
        r[#r+1] = row
    end
    sth:close()
    return r
end

--
-- Model section
--

function PagerModel(args, total)
    local result = {}
    local pager = CreatePager(total, conf.pager.limit, args.page, conf.pager.offset)
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
            r[#r+1]=string.format("%s=%s",g,v)
        end
        path=table.concat(r, '&amp;')
        class = (args.page == p) and "active" or ""
        table.insert(result, {args=path, class=class, page=p})
    end
    return result
end

-- get pkgname with same origin
function SubPackagesModel(pkg)
    local r = {}
    local origins = QueryOrigin(pkg.repo, pkg.origin, pkg.arch)
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
    for k,v in pairs (pkg.deps:split(" ")) do
        -- resolve so deps
        if v:begins('so:') then
            sdpkg = QueryDepends("%"..v.."%", "%", pkg.arch)
            if next(sdpkg) then
                sd = FilterDeps(sdpkg, pkg.repo)
                r[sd.name] = sd
            end
        else
            local name = v:gsub('=.*', '')
            dpkg = QueryDepends("%", name, pkg.arch)
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
        pkgs = QueryRequiredBy("%"..d.."%", pkg.arch)
        for k,v in pairs(pkgs) do
            r[v.name..v.repo] = v
        end
    end
    -- lookup package that depends on pkgname
    pkgs = QueryRequiredBy("%"..pkg.name.."%", pkg.arch)
    for k,v in pairs(pkgs) do
        if turbo.util.is_in(pkg.name, v.deps:split(" ")) then
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
    local r = {}
    if (pkg.name ~= "") then
        r[#r+1] = {head="Package",data=pkg.name}
    end
    if (pkg.version ~= "") then
        r[#r+1] = {head="Version",data=pkg.version}
    end
    if (pkg.desc ~= "") then
        r[#r+1] = {head="Description",data=pkg.desc}
    end
    if (pkg.url ~= "") then
        r[#r+1] = {
            head="Project",
            url={
                path=pkg.url,
                text=pkg.url
            }
        }
    end
    if (pkg.lic ~= "") then
        r[#r+1] = {head="License",data=pkg.lic}
    end
    if (pkg.repo ~= "") then
        r[#r+1] = {head="Repository",data=pkg.repo}
    end
    if (pkg.arch ~= "") then
        r[#r+1] = {head="Arch",data=pkg.arch}
    end
    if (pkg.size ~= "") then
        r[#r+1] = {head="Size",data=human_bytes(pkg.size)}
    end
    if (pkg.installed_size ~= "") then
        r[#r+1] = {head="Install Size", data=human_bytes(pkg.install_size)}
    end
    if (pkg.origin ~= "") then
        r[#r+1] = {
            head="Origin",
            url={
                path=string.format("/package/%s/%s/%s", pkg.repo, pkg.arch, pkg.origin),
                text=pkg.origin
            }
        }
    end
    if (pkg.maintainer ~= "") then
        r[#r+1] = {head="Maintainer",data=format_maintainer(pkg.maintainer)}
    end
    if (pkg.build_time ~= "") then
        r[#r+1] = {head="Build Time",data=pkg.build_time}
    end
    if (pkg.commit ~= "") then
        r[#r+1] = {
            head="Commit",
            url={
                path=string.format("http://git.alpinelinux.org/cgit/aports/commit/?id=%s", pkg.commit),
                text=pkg.commit
            }
        }
    end
    r[#r+1] = {
        head="Contents",
        url={
            path=string.format("/contents?pkgname=%s&arch=%s&repo=%s", pkg.name, pkg.arch, pkg.repo),
            text="Contents of package"
        }
    }
    return r
end

function PackagesModel(pkgs)
    local r = {}
    for k,v in pairs(pkgs) do
        r[k] = {}
        r[k].name = {
            path=string.format("/package/%s/%s/%s", v.repo, v.arch, v.name),
            text=v.name,
            title=v.desc
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
        r[k].lic = v.lic
        r[k].arch = v.arch
        r[k].repo = v.repo
        r[k].maintainer = format_maintainer(v.maintainer)
        r[k].build_time = format_date(v.build_time)
        local fs = QueryFlaggedStatus(v.origin, v.repo, v.version)
        if (fs) then r[k].flagged = {date=fs.date} end
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
    local archs = QueryArchs()
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
    local repos = QueryRepos()
    table.insert(repos, {repo="all"})
    for k,v in pairs(repos) do
        r[k] = {text=v.repo}
        if (v.repo == selected) then
            r[k].selected = "selected"
        end
    end
    return r
end

function PackagesFormModel(name, repo, arch)
    local r = {}
    r.repo = FormRepoModel(repo)
    r.arch = FormArchModel(arch)
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
    local d = {
        filename = (a.filename == "") and "%" or a.filename,
        path = (a.path == "") and "%" or a.path,
        pkgname = (a.pkgname == "") and "%" or a.pkgname,
        repo = (a.repo == "all") and "%" or a.repo,
    }
    m.nav = {package="", content="active"}
    m.alert = self.options.alert:get_msg()
    m.form = ContentsFormModel(a.filename, a.path, a.pkgname, a.repo, a.arch)
    if not (a.filename == "" and a.path == ""  and a.pkgname == "") then
        local contents = QueryContents(d.filename, d.path, d.pkgname, a.arch, d.repo, a.page)
        local count = GetContentsCount(d.filename, d.path, d.pkgname, a.arch, d.repo)
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
        page = tonumber(self:get_argument("page", 1, true)),
    }
    local pkgs = QueryPackages(a.name, a.repo, a.arch, a.page)
    local num = GetPackagesCount(a.name, a.repo, a.arch)
    m.nav = {package="active", content=""}
    m.alert = self.options.alert:get_msg()
    m.form = PackagesFormModel(a.name, a.repo, a.arch)
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
    local pkg = QueryPackage(name, repo, arch)
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
local FlaggedRenderer = class("FlaggedRenderer", turbo.web.RequestHandler)

function FlaggedRenderer:get(repo, origin, version)
    local args = {"flag",repo,origin,version}
    local pkg = QueryPackage(origin, repo)
    --trow an http error if this package doesnt exists
    if not OriginExists(repo, origin, version) then
        error(turbo.web.HTTPError(404, "404 Page not found."))
    -- display alert when origin is already flagged
    elseif QueryFlaggedStatus(origin, repo, version) then
        alert = "This origin has already been flagged"
        self.options.alert:set_msg(alert, "danger")
    end
    local m = FlagModel(pkg)
    m.alert = self.options.alert:get_msg()
    m.header = lustache:render(tpl("header.tpl"), m)
    m.footer = lustache:render(tpl("footer.tpl"), m)
    self:write(lustache:render(tpl("flagged.tpl"), m))
end

-- flagged post function when submitting the form
function FlaggedRenderer:post(repo, origin, version)
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
    elseif QueryFlaggedStatus(origin, repo, version) then
        alert = "This origin has already been flagged"
    -- check for valid email address
    elseif not validate_email(from) then
        alert = "Please provide a valid email address."
    -- verify captha if enabled
    elseif conf.rc.sitekey and not RecaptchaVerify(responce) then
        alert = "Failed to pass recaptcha. Please try again."
    -- flag origin, if failed we display an alert
    elseif not FlagOrigin(repo, origin, version, message) then
        alert = [[ Failed to flag origin package: origin ]]
    -- all is well (we presume)
    else
        args = {"packages"}
        type = "success"
        local pkg = QueryPackage(origin, repo)
        -- Check if we have a valid maintainer recipient
        if validate_email(pkg.maintainer) then
            local subject = "Alpine aport "..origin.." has been flagged out of date"
            self.options.mail:set_from(conf.mail.from)
            self.options.mail:set_rcpt(pkg.maintainer)
            self.options.mail:set_to(pkg.maintainer)
            self.options.mail:set_subject(subject)
            local m = {
                maintainer =  format_maintainer(pkg.maintainer),
                origin = origin,
                from = from,
                message = message
            }
            body = lustache:render(tpl("mail_body.tpl"), m)
            self.options.mail:set_body(body)
            local result = self.options.mail:send()
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

function main()
    local alert = Alert()
    local mail = SendMail()
    turbo.web.Application({
        {"^/$", turbo.web.RedirectHandler, "/packages"},
        {"^/contents$", ContentsRenderer, {alert=alert}},
        {"^/packages$", PackagesRenderer, {alert=alert}},
        {"^/package/(.*)/(.*)/(.*)$", PackageRenderer, {alert=alert}},
        {"^/flag/(.*)/(.*)/(.*)$", FlaggedRenderer, {mail=mail, alert=alert}},
        {"/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
    }):listen(conf.port)
    turbo.ioloop.instance():start()
end

main()
