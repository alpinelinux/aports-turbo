#!/usr/bin/env luajit

-- lua turbo application

local turbo = require "turbo"
local inspect = require "inspect"

function string.begins(str, prefix)
    return str:sub(1,#prefix)==prefix
end

function human_bytes(bytes)
    local mult = 10^(2)
    local size = { 'B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB' }
    local factor = math.floor((string.len(bytes) -1) /3)
    local result = bytes/math.pow(1024, factor)
    return math.floor(result * mult + 0.5) / mult.." "..size[factor+1]
end

local tpl = turbo.web.Mustache.TemplateHelper("./tpl")

local ContentsRenderer = class("ContentsRenderer", turbo.web.RequestHandler)

function ContentsRenderer:get()
    local args = {
        filename = self:get_argument("filename","", true),
        pkgname = self:get_argument("pkgname", "", true),
        arch = self:get_argument("arch", "x86", true),
        page = tonumber(self:get_argument("page", 1, true)),
    }
    -- assign different variables for db query
    local fname = (args.filename == "") and "%" or args.filename
    local pname = (args.pkgname == "") and "%" or args.pkgname
    local table = {}
    if not (fname == "%" and pname == "%") then
        table.rows = QueryContents(fname, pname, args.arch, args.page)
        local rows = (table.rows ~= nil) and (#table.rows) or 0
        table.pager = CreatePagerUri(args, rows)
    end
    table.filename = args.filename
    table.pkgname = args.pkgname
    table[args.arch] = true
    table.contents = true
    table.pkgname = args.pkgname
    table.header = tpl:render("header.tpl", table)
    table.footer = tpl:render("footer.tpl", table)
    self:write(tpl:render(self.options, table))
end

local PackagesRenderer = class("PackagesRenderer", turbo.web.RequestHandler)

function PackagesRenderer:get()
    local args = {
        package = self:get_argument("package","", true),
        arch = self:get_argument("arch", "x86", true),
        repo = self:get_argument("repo", "all", true),
        page = tonumber(self:get_argument("page", 1, true)),
    }
    local table = {}
    local pname = (args.package == "") and "%" or args.package
    local rname = (args.repo == "all") and "%" or args.repo
    local result = QueryPackages(pname, rname, args.arch, args.page)
    if next(result) ~= nil then
        table.rows = result
        table.repo = args.repo
        local rows = (table.rows ~= nil) and (#table.rows) or 0
        table.pager = CreatePagerUri(args, rows)
    end
    table[args.arch] = true
    table[args.repo] = true
    table.packages = true
    table.package = args.package
    table.header = tpl:render("header.tpl", table)
    table.footer = tpl:render("footer.tpl", table)
    local page = tpl:render(self.options, table)
    self:write(page)
end

local PackageRenderer = class("PackageRenderer", turbo.web.RequestHandler)

function PackageRenderer:get(arch, name)
    local table = QueryPackage(name, arch)
    if table ~= nil then
        table.install_size = human_bytes(table.install_size)
        table.size = human_bytes(table.size)
        table.deps = QueryDeps(table.deps, arch)
        table.deps_qty = (table.deps ~= nil) and #table.deps or "0"
        table.reqbys = QueryRequiredBy(table.provides, arch)
        table.reqbys_qty = (table.reqbys ~= nil) and #table.reqbys or "0"
        table.subpkgs = QuerySubPackages(table.origin, table.name, arch)
        table.subpkgs_qty = (table.subpkgs ~= nil) and #table.subpkgs or "0"
        table.maintainer = (table.maintainer ~= "") and string.gsub(table.maintainer, '<.*>', '') or "None"
        for k in pairs (table) do
            if table[k] == "" then
                table[k] = nil
            end
        end
    else
        table = {}
    end
    table.header = tpl:render("header.tpl")
    table.footer = tpl:render("footer.tpl")
    local page = tpl:render(self.options, table)
    self:write(page)
end

function QueryContents(filename, pkgname, arch, page)
    require('DBI')
    local offset = (tonumber(page) == nil) and 0 or tonumber(page)*50
    local dbh = assert(DBI.Connect('SQLite3', 'db/filelist.db'))
    local sth = assert(dbh:prepare('select * from filelist where file like ? and pkgname like ? and arch like ? limit ?,50'))
    sth:execute(filename, pkgname, arch, (page - 1) * 50)
    local r = {}
    for row in sth:rows(true) do
        r[#r + 1] = {
            file = "/" .. row.path .. "/" .. row.file,
            pkgname = row.pkgname,
            repo = row.repo,
            arch = row.arch,
        }
    end
    sth:close()
    if next(r) ~= nil then
        return r
    end
end

function QueryPackages(package, repo, arch, page)
    require('DBI')
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name, version, url, lic, desc, arch, repo, maintainer, datetime(build_time, \'unixepoch\') as build_time from apkindex where name like ? and repo like ? and arch like ? ORDER BY build_time DESC limit ?,50'))
    sth:execute(package, repo, arch, (page - 1) * 50)
    local r = {}
    for row in sth:rows(true) do
        r[#r+1] = {
                package = row.name,
                version = row.version,
                project = row.url,
                license = row.lic,
                desc = row.desc,
                arch = row.arch,
                repo = row.repo,
                maintainer = (row.maintainer ~= "") and string.gsub(row.maintainer, '<.*>', '') or "None",
                bdate = row.build_time
        }
    end
    sth:close()
    return r
end

function QueryPackage(name, arch)
    require('DBI')
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select *, datetime(build_time, \'unixepoch\') as build_time from apkindex where name like ? and arch like ? limit 1'))
    sth:execute(name, arch)
    local r = sth:fetch(true)
    sth:close()
    return r
end

function QueryDeps(deps, arch)
    require('DBI')
    local names = {}
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name from apkindex where provides like ? and arch like ?'))
    for _,k in pairs (deps:split(" ")) do
        if k:begins('so:') then
            sth:execute("%"..k.."%", arch)
            local l = sth:fetch(true)
            if l ~= nil then
                names[l.name] = l.name:gsub('=.*', '')
            end
        else
            names[k] = k:gsub('=.*', '')
        end
    end
    sth:close()
    local r = {}
    for _,name in pairs (names) do
        r[#r+1] = {dep=name}
    end
    if next(r) ~= nil then
        return r
    end
end

function QueryRequiredBy(provides, arch)
    require('DBI')
    local names = {}
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name from apkindex where deps like ? and arch like ?'))
    for _,d in pairs (provides:split(" ")) do
        if d:begins('so:') then
            d = string.gsub(d, '=.*', '')
            sth:execute("%"..d.."%", arch)
            for row in sth:rows(true) do
                if row ~= nil then
                    names[row.name] = row.name
                end
            end
        end
    end
    sth:close()
    local r = {}
    for _,name in pairs (names) do
        r[#r+1] = {reqby=name}
    end
    if next(r) ~= nil then
        return r
    end
end

function QuerySubPackages(origin, name, arch)
    require('DBI')
    local names = {}
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name from apkindex where origin like ? and arch like ?'))
    sth:execute(origin, arch)
    local r = {}
    for row in sth:rows(true) do
        if row.name ~= name then
            r[#r+1] = {subpkg=row.name}
        end
    end
    sth:close()
    if next(r) ~= nil then
        return r
    end
end

function CreatePagerUri(args, rows)
    local r,p,n,page = {},{},{}
    for get,value in pairs (args) do
        if (get == 'page') then
            -- do not include page on first page
            if value > 2 then
                p[#p + 1] = get.."="..(value-1)
            end
            n[#n + 1] = get.."="..(value+1)
        else
            p[#p + 1] = get.."="..(value)
            n[#n + 1] = get.."="..(value)
        end
    end
    -- show pager when rows are 50+
    if rows >= 50 then
        r.next = table.concat(n, '&amp;')
        r.prev = table.concat(p, '&amp;')
    end
    -- do not show prev on first page
    if args.page == 1 and rows >= 50 then
        r.prev = nil
    end
    -- show prev on last page
    if args.page ~= 1 and (rows >= 0 and rows <= 50) then
        r.prev = table.concat(p, '&amp;')
    end
    if next(r) ~= nil then
        r.page = args.page
        return {r}
    end
end

turbo.web.Application({
    {"^/$", turbo.web.RedirectHandler, "/packages"},
    {"^/contents$", ContentsRenderer, "contents.tpl"},
    {"^/packages$", PackagesRenderer, "packages.tpl"},
    {"^/package/(.*)/(.*)$", PackageRenderer, "package.tpl"},
    {"/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
}):listen(8888)
turbo.ioloop.instance():start()
