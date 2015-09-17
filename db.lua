local cjson = require "cjson"
local sqlite3 = require('lsqlite3')

local M = {}

M.db = class("db")

function M.db:initialize()
    self.db = self.db or sqlite3.open("db/aports.db")
end

function M.db:select_query(select, from, operators)
    local result = { args = {}, sql = "" }
    local exclude = {"%", "", "all"}
    local r = {}
    for k,v in pairs(operators) do
        if not (turbo.util.is_in(v, exclude)) then
            if string.match(v, "%%") then
                r[#r+1] = string.format([[%s like ?]],k)
            else
                r[#r+1] = string.format([[%s=?]],k)
            end
            table.insert(result.args, v)
        end
    end
    result.sql = next(r) and
        string.format("select %s from %s where %s", select, from, table.concat(r, " and "))
        or string.format("select %s from %s", select, from)
    return result
end

function M.db:msg(msg)
    if conf.debug then print(msg) end
end

function M.db:sha1sum(str)
    local digest = turbo.hash.SHA1(str)
    digest:finalize()
    return digest:hex()
end

M.apkindex = class("apkindex", M.db)

function M.apkindex:initialize()
    self.csum = {}
    M.db.initialize(self)
    self.db:exec([[ CREATE TABLE IF NOT EXISTS apkindex('name' text, 'version' text, 'description' text,
        'url' text, 'license' text, 'arch' text, 'depends' text, 'csum' text,
        'size' integer, 'installed_size' integer, 'provides' text,
        'installed_if' text, 'origin' text, 'maintainer' text, 'build_time' integer,
        'commit' text, 'repo' text) ]]
    )
end

function M.apkindex:create()
    if self:has_changes() then
        self:msg("apkindex changes found, importing.")
        self:create_table()
        self:process()
        self:replace_table()
        self:msg("apkindex: finished importing.")
    else
        self:msg("apkindex: no changes found.")
    end
end

function M.apkindex:format()
    return {
        P = "name",
        V = "version",
        T = "description",
        U = "url",
        L = "license",
        A = "arch",
        D = "depends",
        C = "csum",
        S = "size",
        I = "installed_size",
        p = "provides",
        i = "install_if",
        o = "origin",
        m = "maintainer",
        t = "build_time",
        c = "commit",
    }
end

function M.apkindex:create_table()
    self.db:exec([[ CREATE TABLE apkindex_tmp('name' text, 'version' text, 'description' text,
        'url' text, 'license' text, 'arch' text, 'depends' text, 'csum' text,
        'size' integer, 'installed_size' integer, 'provides' text,
        'installed_if' text, 'origin' text, 'maintainer' text, 'build_time' integer,
        'commit' text, 'repo' text) ]]
    )
end

function M.apkindex:replace_table()
    self.db:exec([[ drop table apkindex ]])
    self.db:exec([[ alter table apkindex_tmp rename to apkindex ]])
    self.db:exec([[ create index name on apkindex_tmp(name) ]])
end

function M.apkindex:get_index(repo, arch)
    local r = {}
    local result = {}
    local cmdfmt = "curl -s '%s' | tar -O -zx APKINDEX"
    local index = string.format("%s/edge/%s/%s/APKINDEX.tar.gz", conf.mirror, repo, arch)
    local f = io.popen(cmdfmt:format(index))
    for line in f:lines() do
        if (line ~= "") then
            local k,v = line:match("^(%a):(.*)")
            r[k] = v
        else
            table.insert(result, r)
            r = {}
        end
    end
    f:close()
    return result
end

function M.apkindex:is_new(repo, arch)
    local cmdfmt = "curl -s '%s' | tar -O -zx APKINDEX"
    local index = string.format("%s/edge/%s/%s/APKINDEX.tar.gz", conf.mirror, repo, arch)
    local f = io.popen(cmdfmt:format(index))
    local file = f:read("*all")
    f:close()
    local sha1sum = self:sha1sum(file)
    if not self.csum[repo] then 
        self.csum[repo] = {}
    else 
        if (self.csum[repo][arch] == sha1sum) then
            return false
        end
    end
    self.csum[repo][arch] = sha1sum
    return true
end

function M.apkindex:import(repo, arch)
    local sql = [[ insert into apkindex_tmp ("name", "version", "description", "url", "license",
        "arch", "depends", "csum", "size", "installed_size", "provides", "installed_if", "origin",
        "maintainer", "build_time", "commit", "repo") 
        values (:name, :version, :description, :url, :license, :arch, :depends,
        :csum, :size, :installed_size, :provides, :installed_if, :origin, :maintainer,
        :build_time, :commit, :repo) ]]
    local stmt = self.db:prepare(sql)
    self.db:exec([[ begin transaction ]])
    local packages = self:get_index(repo, arch)
    for k,v in pairs(packages) do
        local s = {}
        for pk,pv in pairs(self:format()) do
            s[pv] = v[pk] and v[pk] or ""
        end
        s.repo = repo
        stmt:bind_names(s)
        stmt:step()
        stmt:reset()
    end
    self.db:exec([[ end transaction ]])
    stmt:finalize()
end

function M.apkindex:process()
    for _,repo in ipairs(conf.repo) do
        for _,arch in ipairs(conf.arch) do
            self:import(repo, arch)
        end
    end
end

function M.apkindex:has_changes()
    local changes = false
    for _,repo in ipairs(conf.repo) do
        for _,arch in ipairs(conf.arch) do
            if self:is_new(repo, arch) then
                changes = true
            end
        end
    end
    return changes
end

-- get a list of packages
function M.apkindex:get_packages(name, repo, arch, maintainer, page)
    local r = {}
    maintainer = (maintainer == "all") and "all" or string.format("%s%s%s","%",maintainer,"%")
    local ops = {name=name, repo=repo, arch=arch, maintainer=maintainer}
    local res = self:select_query("*", "apkindex", ops)
    res.sql = string.format("%s ORDER BY build_time DESC LIMIT ?,%s", res.sql, conf.pager.limit)
    table.insert(res.args, (page - 1) * conf.pager.limit)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return r
end

-- get all packages whith deps and arch
function M.apkindex:get_required_by(deps, arch)
    local r = {}
    local ops = {depends=deps, arch=arch}
    local res = self:select_query("*", "apkindex", ops)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return r
end

-- get a pacakge or return false if not found
function M.apkindex:get_package(ops)
    local r = {}
    local res = self:select_query("*", "apkindex", ops)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return next(r) and r[1] or false
end

-- get all packages which have certain provides
function M.apkindex:get_depends(provides, name, arch)
    local r = {}
    local ops = {provides=provides, name=name, arch=arch}
    local res = self:select_query("*", "apkindex", ops)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return r
end

-- count query to help our pager
function M.apkindex:count_packages(name, repo, arch, maintainer)
    if maintainer ~= "all" then
        maintainer = string.format("%s%s%s","%",maintainer,"%")
    end
    local ops = {name=name, repo=repo, arch=arch, maintainer=maintainer}
    local res = self:select_query("count(*)", "apkindex", ops)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    stmt:step()
    local r = stmt:get_value(0)
    stmt:finalize()
    return r
end

-- get all packages with same origin in the same repo
-- with (optional) arch
function M.apkindex:get_origin(repo, origin, arch)
    local r = {}
    local ops = {repo=repo, origin=origin, arch=arch}
    local res = self:select_query("*", "apkindex", ops)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return r
end

function M.apkindex:get_distinct(column)
    local r = {}
    local sql = string.format([[ select distinct %s from apkindex ]], column)
    for row in self.db:nrows(sql) do
        r[#r+1] = row
    end
    return r
end

---
-- Filelist class
---

M.filelist = class("filelist", M.db)

function M.filelist:initialize()
    self.csum = {}
    M.db.initialize(self)
    self.db:exec([[ CREATE TABLE IF NOT EXISTS filelist ('file' text, 'path' text, 'pkgname' text, 'repo' text, 'arch' text) ]])
end

function M.filelist:create()
    if self:has_changes() then
        self:msg("filelist: changes found, importing.")
        self:create_table()
        self:process()
        self:replace_table()
        self:msg("filelist: finished importing.")
    else
        self:msg("filelist: no changes found.")
    end
end

function M.filelist:create_table()
    self.db:exec([[ create table filelist_tmp ('file' text, 'path' text, 'pkgname' text, 'repo' text, 'arch' text) ]])
end

function M.filelist:replace_table()
    self.db:exec([[ drop table filelist ]])
    self.db:exec([[ alter table filelist_tmp rename to filelist ]])
    self.db:exec([[ create index pkgname on filelist (pkgname) ]])
    self.db:exec([[ create index file on filelist (file) ]])
    self.db:exec([[ create index path on filelist (path) ]])
end

function M.filelist:get_json(repo, arch)
    local url = string.format("%s/filelist/%s-%s.json.gz", conf.mirror, repo, arch)
    local curlfmt = "curl -s '%s' | gunzip"
    local f = io.popen(curlfmt:format(url))
    local json = f:read("*all")
    f:close()
    return json
end

function M.filelist:import(repo, arch)
    local sql = [[ insert into filelist_tmp('file', 'path', 'pkgname', 'repo', 'arch') values (?,?,?,?,?) ]]
    local stmt = self.db:prepare(sql)
    local json = self:get_json(repo, arch)
    local pkgs = cjson.decode(json)
    self.db:exec([[ begin transaction ]])
    for pkgname,files in pairs(pkgs) do
        for _,file in ipairs(files) do
            stmt:bind_values(file[1], file[2], pkgname, repo, arch)
            stmt:step()
            stmt:reset()
        end
    end
    self.db:exec([[ end transaction ]])
    stmt:finalize()
end
    
function M.filelist:process()
    for _,repo in ipairs(conf.repo) do
        for _,arch in ipairs(conf.arch) do
            self:import(repo, arch)
        end
    end
end

-- should be shared
function M.filelist:is_new(repo, arch)
    local json = self:get_json(repo, arch)
    local sha1sum = self:sha1sum(json)
    if not self.csum[repo] then 
        self.csum[repo] = {}
    else 
        if (self.csum[repo][arch] == sha1sum) then
            return false
        end
    end
    self.csum[repo][arch] = sha1sum
    return true
end

function M.filelist:has_changes()
    local changes = false
    for _,repo in ipairs(conf.repo) do
        for _,arch in ipairs(conf.arch) do
            if self:is_new(repo, arch) then
                changes = true
            end
        end
    end
    return changes
end

function M.filelist:count_files(file, path, pkgname, arch, repo)
    local args = {file=file, path=path, pkgname=pkgname, arch=arch, repo=repo}
    local res = self:select_query("count(*)", "filelist", args)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    stmt:step()
    local r = stmt:get_value(0)
    stmt:finalize()
    return r
end

-- get the file list from database for a specific package
function M.filelist:get_files(file, path, pkgname, arch, repo, page)
    local r = {}
    local args = {file=file,path=path,pkgname=pkgname,arch=arch,repo=repo}
    local res = self:select_query("*", "filelist", args)
    res.sql = string.format("%s LIMIT ?,%s", res.sql, conf.pager.limit)
    table.insert(res.args, (page - 1) * conf.pager.limit)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return r
end

---
-- flagged class
---

M.flagged = class("flagged", M.db)

function M.flagged:initialize()
    M.db.initialize(self)
    self.db:exec([[ CREATE TABLE IF NOT EXISTS flagged (origin text, repo text, version text, date integer, message text) ]])
end

function M.flagged:get_status(origin, repo, version)
    local r = {}
    local ops = {origin=origin, repo=repo, version=version}
    local res = self:select_query("*", "flagged", ops)
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return next(r) and r[1] or false
end

function M.flagged:get_flagged(ops)
    local r = {}
    local res = self:select_query("*", "flagged", ops)
    res.sql = res.sql .. " ORDER BY date DESC"
    local stmt = self.db:prepare(res.sql)
    stmt:bind_names(res.args)
    for row in stmt:nrows() do
        r[#r+1] = row
    end
    stmt:finalize()
    return r
end

function M.flagged:flag_origin(repo, origin, version, message)
    local sql = [[ insert into flagged(repo, origin, version, date, message)
        values(?, ?, ?, strftime('%s', 'now'), ?) ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_values(repo, origin, version, message)
    local r = stmt:step()
    stmt:finalize()
    return r
end

return M
