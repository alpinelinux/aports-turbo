#!/usr/bin/env luajit

-- lua turbo application

local turbo = require "turbo"
local inspect = require "inspect"

function string.begins(str, prefix)
    return str:sub(1,#prefix)==prefix
end

local tpl = turbo.web.Mustache.TemplateHelper("./tpl")

local ContentsRenderer = class("ContentsRenderer", turbo.web.RequestHandler)

function ContentsRenderer:get()
    local args = {
        filename = self:get_argument("filename","", true),
        pkgname = self:get_argument("pkgname", "", true),
        arch = self:get_argument("arch", "x86", true),
        page = self:get_argument("page", "", true),
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
    print(inspect(table.pager))
    table.page = (args.page == "") and "1" or args.page
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
    }
    local table = { [args.arch] = true }
    if args.package == "" then
        args.package = "%"
    end
    local result = QueryPackages(args)
    if next(result) ~= nil then
        table.rows = result
    end
    table.packages = true
    table.header = tpl:render("header.tpl", table)
    table.footer = tpl:render("footer.tpl", table)
    local page = tpl:render(self.options, table)
    self:write(page)
end

local PackageRenderer = class("PackageRenderer", turbo.web.RequestHandler)

function PackageRenderer:get(arch, name)
    local table = QueryPackage(name, arch)
    if table ~= nil then
        table.deps = QueryDeps(table.deps)
        table.reqbys = QueryRequiredBy(table.provides)
        table.subpkgs = QuerySubPackages(table.origin, table.name)
        table.maintainer = string.gsub(table.maintainer, '<.*>', '')
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
    sth:execute(filename, pkgname, arch, offset)
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

function QueryPackages(terms)
    require('DBI')
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name, version, url, lic, desc, arch, maintainer, datetime(build_time, \'unixepoch\') as build_time from apkindex where name like ? ORDER BY build_time DESC limit 100'))
    sth:execute(terms.package)
    local r = {}
    for row in sth:rows(true) do
    r[#r+1] = {
            package = row.name,
            version = row.version,
            project = row.url,
            license = row.lic,
            desc = row.desc,
            arch = row.arch,
            repo = "unk",
            maintainer = string.gsub(row.maintainer, '<.*>', ''),
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

function QueryDeps(deps)
    require('DBI')
    local names = {}
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name from apkindex where provides like ?'))
    for _,k in pairs (deps:split(" ")) do
        if k:begins('so:') then
            sth:execute("%"..k.."%")
            local l = sth:fetch(true)
            if l ~= nil then
                names[l.name] = l.name
            end
        else
            names[k] = k
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

function QueryRequiredBy(provides)
    require('DBI')
    local names = {}
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name from apkindex where deps like ?'))
    for _,d in pairs (provides:split(" ")) do
        if d:begins('so:') then
            d = string.gsub(d, '=.*', '')
            sth:execute("%"..d.."%")
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

function QuerySubPackages(origin, name)
    require('DBI')
    local names = {}
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name from apkindex where origin like ?'))
    sth:execute(origin)
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
    local r,p,n = {},{},{};
    for get,value in pairs (args) do
        if (get == 'page') then
            value = (tonumber(value)) and tonumber(value) or 1
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
    if args.page == "" and rows >= 50 then
        r.prev = nil
    end
    -- show prev on last page
    if args.page ~= "" and (rows >= 0 and rows <= 50) then
        r.prev = table.concat(p, '&amp;')
    end
    if next(r) ~= nil then
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
