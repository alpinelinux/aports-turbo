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
        arch = self:get_argument("arch", "x86", true),
    }
    local table = { [args.arch] = true }
    if args.filename ~= "" then
        local result = QueryContents(args)
        if next(result) ~= nil then
            table.rows = result
        end
    end
    table.contents = true
    table.filename = args.filename
    table.header = tpl:render("header.tpl", table)
    table.footer = tpl:render("footer.tpl", table)
    local page = tpl:render(self.options, table)
    self:write(page)
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

function PackageRenderer:get(arch, pkgname)
    local fields = {}
    local table = {}
    fields.arch = arch
    fields.pkgname = pkgname
    local result = QueryPackage(fields)
    -- check for empty values and destroy them
    if result ~= nil then
        table = result
        table.deps = QueryDeps(table.deps)
        table.maintainer = string.gsub(table.maintainer, '<.*>', '')
        for k in pairs (table) do
            if table[k] == "" then
                table[k] = nil
            end
        end
    end
    table.header = tpl:render("header.tpl")
    table.footer = tpl:render("footer.tpl")
    local page = tpl:render(self.options, table)
    self:write(page)
end

function QueryContents(terms)
    require('DBI')
    local dbh = assert(DBI.Connect('SQLite3', 'db/filelist.db'))
    local sth = assert(dbh:prepare('select * from filelist where file like ? and arch like ? limit 100'))
    sth:execute(terms.filename, terms.arch)
    local r = {}
    for row in sth:rows(true) do
        r[#r + 1] = {
            file = "/" .. row.path .. "/" .. row.file,
            pkgname = row.pkgname,
            repo = row.repo,
            arch = row.arch,
        }
    end
    return r
end

function QueryPackages(terms)
    require('DBI')
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select name, version, url, lic, desc, arch, maintainer, datetime(build_time, \'unixepoch\') as build_time from apkindex where name like ? ORDER BY build_time DESC limit 100'))
    sth:execute(terms.package)
    local r = {}
    for row in sth:rows(true) do
        r[#r + 1] = {
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
    return r
end

function QueryPackage(fields)
    require('DBI')
    local dbh = assert(DBI.Connect('SQLite3', 'db/apkindex.db'))
    local sth = assert(dbh:prepare('select *, datetime(build_time, \'unixepoch\') as build_time from apkindex where name like ? and arch like ? limit 1'))
    sth:execute(fields.pkgname, fields.arch)
    local r = {}
    r = sth:fetch(true)
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
    local r = {}
    for _,name in pairs (names) do
        r[#r+1] = {dep=name}
    end
    if next(r) ~= nil then
        return r
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
