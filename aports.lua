#!/usr/bin/env luajit

-- lua turbo application

local turbo = require "turbo"
local dbi = require "DBI"

local apkindex = assert(dbi.DBI.Connect('SQLite3', 'db/apkindex.db'))
local filelist = assert(dbi.DBI.Connect('SQLite3', 'db/filelist.db'))

function string.begins(str, prefix)
    return str:sub(1,#prefix)==prefix
end

function urlencode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n")
        str = string.gsub (str, "([^%w ])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
        str = string.gsub (str, " ", "+")
    end
    return str
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
        filename = self:get_argument("filename", "", true),
        path = self:get_argument("path", "", true),
        pkgname = self:get_argument("pkgname", "", true),
        arch = self:get_argument("arch", "x86_64", true),
        page = tonumber(self:get_argument("page", 1, true)),
    }
    -- assign different variables for db query
    local fname = (args.filename == "") and "%" or args.filename
    local paname = (args.path == "") and "%" or args.path
    local pname = (args.pkgname == "") and "%" or args.pkgname
    local table = {}
    if not (fname == "%" and pname == "%") then
        table.rows = QueryContents(fname, paname, pname, args.arch, args.page)
        local rows = (table.rows ~= nil) and (#table.rows) or 0
        table.pager = CreatePagerUri(args, rows)
    end
    table.filename = args.filename
    table.pkgname = args.pkgname
    table.path = args.path
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
        arch = self:get_argument("arch", "x86_64", true),
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

function PackageRenderer:get(repo, arch, name)
    local table = QueryPackage(name, repo, arch)
    if table ~= nil then
        table.install_size = human_bytes(table.install_size)
        table.size = human_bytes(table.size)
        table.deps = QueryDeps(table.deps, arch)
        table.deps_qty = (table.deps ~= nil) and #table.deps or "0"
        table.reqbys = QueryRequiredBy(table.provides, arch, name)
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

function QueryContents(filename, path, pkgname, arch, page)
    local sql = [[ select * from filelist where file like ? and path like ?
        and pkgname like ? and arch like ? limit ?,50 ]]
    local sth = assert(filelist:prepare(sql))
    sth:execute(filename, path, pkgname, arch, (page - 1) * 50)
    local r = {}
    for row in sth:rows(true) do
        row.file = "/" .. row.path .. "/" .. row.file
        r[#r + 1] =  row
    end
    sth:close()
    if next(r) ~= nil then
        return r
    end
end

function QueryPackages(package, repo, arch, page)
    local sql = [[ select name as package, version, url as project,
        lic as license, desc, arch, repo, maintainer,
        datetime(build_time, 'unixepoch') as bdate from apkindex
        where name like ? and repo like ? and arch like ?
        ORDER BY build_time DESC limit ?,50 ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute(package, repo, arch, (page - 1) * 50)
    local r = {}
    for row in sth:rows(true) do
        row.maintainer = (row.maintainer ~= "") and
            string.gsub(row.maintainer, '<.*>', '') or "None"
        r[#r+1] = row
    end
    sth:close()
    return r
end

function QueryPackage(name, repo, arch)
    local sql = [[ select *, datetime(build_time, 'unixepoch') as build_time
        from apkindex where name like ? and repo like ? and arch like ? limit 1 ]]
    local sth = assert(apkindex:prepare(sql))
    sth:execute(name, repo, arch)
    local r = sth:fetch(true)
    sth:close()
    return r
end

function QueryDeps(deps, arch)
    local names = {}
    local sql1 = [[ select name,repo from apkindex where provides like ?
        and arch like ? ]]
    local sth1 = assert(apkindex:prepare(sql1))
    local sql2 = [[ select repo from apkindex where name like ? limit 1 ]]
    local sth2 = assert(apkindex:prepare(sql2))
    for _,k in pairs (deps:split(" ")) do
        -- resolve so deps
        if k:begins('so:') then
            sth1:execute("%"..k.."%", arch)
            local l = sth1:fetch(true)
            if l ~= nil then
                names[l.name] = l.repo
            end
        -- get repo from pkgname, in case of multiple results (same pkgname)
        -- we use the first result
        else
            sth2:execute(k)
            local m = sth2:fetch(true)
            if m ~= nil then
                names[k] = m.repo
            end
        end
    end
    sth1:close()
    sth2:close()
    -- reindex table for mustage templating
    local r = {}
    for name,repo in pairs (names) do
        r[#r+1] = {dep=name:gsub('=.*', ''), repo=repo}
    end
    if next(r) ~= nil then
        return r
    end
end

function QueryRequiredBy(provides, arch, name)
    local names = {}
    local sql = [[ select name,deps,repo from apkindex where deps like ?
        and arch like ? ]]
    local sth = assert(apkindex:prepare(sql))
    -- lookup deps based on provides
    for _,d in pairs (provides:split(" ")) do
        if d:begins('so:') then
            d = string.gsub(d, '=.*', '')
            sth:execute("%"..d.."%", arch)
            for r in sth:rows(true) do
                if r ~= nil then
                    names[r.name .. r.repo] = {repo=r.repo,name=r.name}
                end
            end
        end
    end
    -- lookup deps based on pkgname
    sth:execute("%"..name.."%", arch)
    for r in sth:rows(true) do
        if r ~= nil then
            if turbo.util.is_in(name, r.deps:split(" ")) then
                names[r.repo .. r.name] = {repo=r.repo,name=r.name}
            end
        end
    end
    sth:close()
    -- reindex table for mustache templating
    local s = {}
    for _,rn in pairs (names) do
        s[#s+1] = {name=rn.name,repo=rn.repo}
    end
    if next(s) ~= nil then
        return s
    end
end

function QuerySubPackages(origin, name, arch)
    local names = {}
    local sql = [[ select name from apkindex where origin like ?
        and arch like ? ]]
    local sth = assert(apkindex:prepare(sql))
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
            value = urlencode(value)
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
    {"^/package/(.*)/(.*)/(.*)$", PackageRenderer, "package.tpl"},
    {"/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
}):listen(8888)
turbo.ioloop.instance():start()
