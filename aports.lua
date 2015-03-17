#!/usr/bin/env luajit

-- lua turbo application

local turbo = require "turbo"

local tpl = turbo.web.Mustache.TemplateHelper("./tpl")

local ContentsRenderer = class("ContentsRenderer", turbo.web.RequestHandler)

function ContentsRenderer:get()
    local table = {}
    local args = {
        filename = self:get_argument("filename","", true),
        arch = self:get_argument("arch", "x86", true),
    }
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
    local table = {}
    local args = {
        package = self:get_argument("package","", true)
    }
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
    result = QueryPackage(fields)
    if result ~= nil then
        table = result
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

turbo.web.Application({
    {"^/$", turbo.web.RedirectHandler, "/packages"},
    {"^/contents$", ContentsRenderer, "contents.tpl"},
    {"^/packages$", PackagesRenderer, "packages.tpl"},
    {"^/package/(.*)/(.*)$", PackageRenderer, "package.tpl"},
    {"/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
}):listen(8888)
turbo.ioloop.instance():start()
