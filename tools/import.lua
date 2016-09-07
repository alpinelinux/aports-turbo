local sqlite    = require("lsqlite3")
local turbo     = require("turbo")

conf            = require("config")
local cntrl     = require("controller")
local utils     = require("utils")

---
-- import
---

local import    = class("import")

function import:initialize()
    self.db = sqlite.open(conf.db.path)
    self.db:exec("PRAGMA foreign_keys=ON")
    self.db:exec("PRAGMA journal_mode=WAL")
    if conf.db.init then self:createTables() end
end

function import:finalize()
    self.db:close()
end

function import:split(d,s)
    local r = {}
    for i in s:gmatch(d) do table.insert(r,i) end
    return r
end

function import:log(msg)
    if conf.logging then
        if conf.logging == "syslog" then
            os.execute("logger "..msg)
        else
            print(msg)
        end
    end
end

function import:fileExists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

-- keys used in alpine linux repository index
function import:indexFormat(k)
    local f = {
        P = "name",
        V = "version",
        T = "description",
        U = "url",
        L = "license",
        A = "arch",
        D = "depends",
        C = "checksum",
        S = "size",
        I = "installed_size",
        p = "provides",
        i = "install_if",
        o = "origin",
        m = "maintainer",
        t = "build_time",
        c = "commit",
    }
    return k and f[k] or f
end

function import:createTables()
    self.db:exec( [[ CREATE TABLE IF NOT EXISTS 'packages' (
        'id' INTEGER primary key,
        'name' TEXT,
        'version' TEXT,
        'description' TEXT,
        'url' TEXT,
        'license' TEXT,
        'arch' TEXT,
        'branch' TEXT,
        'repo' TEXT,
        'checksum' TEXT,
        'size' INTEGER,
        'installed_size' INTEGER,
        'origin' TEXT,
        'maintainer' INTEGER,
        'build_time' INTEGER,
        'commit' TEXT,
        'fid' INTEGER
    ) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_name' on 'packages' (name) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_maintainer' on 'packages' (maintainer) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_build_time' on 'packages' (build_time) ]])
    self.db:exec([[ CREATE TABLE IF NOT EXISTS 'files' (
        'id' INTEGER primary key,
        'file' TEXT,
        'path' TEXT,
        'pkgname' TEXT,
        'pid' INTEGER REFERENCES packages(id) ON DELETE CASCADE
    ) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'files_file' on 'files' (file) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'files_path' on 'files' (path) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'files_pkgname' on 'files' (pkgname) ]])
    self.db:exec([[ CREATE INDEX IF NOT EXISTS 'files_pid' on 'files' (pid) ]])
    local field = [[ CREATE TABLE IF NOT EXISTS '%s' (
        'name' TEXT,
        'version' TEXT,
        'operator' TEXT,
        'pid' INTEGER REFERENCES packages(id) ON DELETE CASCADE
    )]]
    for _,v in pairs(conf.db.fields) do
        self.db:exec(string.format(field,v))
        self.db:exec(string.format([[CREATE INDEX IF NOT EXISTS '%s_name' on '%s' (name)]], v, v))
        self.db:exec(string.format([[CREATE INDEX IF NOT EXISTS '%s_pid' on '%s' (pid)]], v, v))
    end
    self.db:exec([[CREATE TABLE IF NOT EXISTS maintainer (
        'id' INTEGER primary key,
        'name' TEXT,
        'email' TEXT
    )]])
    self.db:exec([[CREATE INDEX IF NOT EXISTS 'maintainer_name'
        on maintainer (name)]])
    self.db:exec([[ CREATE TABLE IF NOT EXISTS 'repoversion' (
        'branch' TEXT,
        'repo' TEXT,
        'arch' TEXT,
        'version' TEXT
    )]])
    self.db:exec([[CREATE UNIQUE INDEX IF NOT EXISTS 'repoversion_version'
        on repoversion (branch, repo, arch)]])
    self.db:exec([[ CREATE TABLE IF NOT EXISTS 'flagged' (
        'fid' INTEGER primary key,
        'created' INTEGER,
        'reporter' TEXT,
        'new_version' TEXT,
        'message' TEXT
    ) ]])
end

---
-- get the current git describe from DESCRIPTION file
---
function import:getRepoVersion(branch, repo, arch)
    local index = string.format("%s/%s/%s/%s/APKINDEX.tar.gz",
        conf.mirror, branch, repo, arch)
    local f = io.popen(string.format("tar -Ozx -f '%s' DESCRIPTION", index))
    for line in f:lines() do
        return line
    end
end

function import:getLocalRepoVersion(branch, repo, arch)
    local sql = [[ select version from repoversion
        where branch = ? and repo = ? and arch = ? ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_values(branch, repo, arch)
    local r = (stmt:step() == sqlite.ROW) and stmt:get_value(0) or false
    stmt:finalize()
    return r
end

function import:updateLocalRepoVersion(branch, repo, arch, version)
    local sql = [[ insert or replace into repoversion ('version', 'branch', 'repo', 'arch')
        VALUES (:version, :branch, :repo, :arch) ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_names({version=version,branch=branch,repo=repo,arch=arch})
    stmt:step()
    stmt:finalize()
end

---
-- compare remote repo version with local and return remote version if updated
---
function import:repoUpdated(branch, repo, arch)
    local v = self:getRepoVersion(branch, repo, arch)
    local l = self:getLocalRepoVersion(branch, repo, arch)
    if (v ~= l) then return v end
end

function import:getApkIndex(branch, repo, arch)
    local r,i = {},{}
    local index = string.format("%s/%s/%s/%s/APKINDEX.tar.gz",
        conf.mirror, branch, repo, arch)
    local f = io.popen(string.format("tar -Ozx -f '%s' APKINDEX", index))
    for line in f:lines() do
        if (line ~= "") then
            local k,v = line:match("^(%a):(.*)")
            local key = self:indexFormat(k)
            r[key] = k:match("^[Dpi]$") and self:split("%S+", v) or v
        else
            local nv = string.format("%s-%s", r.name, r.version)
            r.repo = repo
            r.branch = branch
            i[nv] = r
            r = {}
        end
    end
    f:close()
    return i
end

function import:getChanges(branch, repo, arch)
    local del = {}
    local add = self:getApkIndex(branch, repo, arch)
    local sql = [[SELECT branch, repo, arch, name,version FROM 'packages'
        WHERE branch = ?
        AND repo = ?
        AND arch = ?
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_values(branch,repo,arch)
    for r in stmt:nrows() do
        local nv = string.format("%s-%s", r.name, r.version)
        if add[nv] then
            add[nv] = nil
        else
            del[nv] = r
        end
    end
    stmt:finalize()
    return add,del
end

function import:addPackages(branch, add)
    for _,pkg in pairs(add) do
        local apk = string.format("%s/%s/%s/%s/%s-%s.apk",
            conf.mirror, branch, pkg.repo, pkg.arch, pkg.name, pkg.version)
        if self:fileExists(apk) then
            self:log(string.format("Adding: %s/%s/%s/%s-%s", branch, pkg.repo, pkg.arch, pkg.name, pkg.version))
            pkg.maintainer = self:addMaintainer(pkg.maintainer)
            local pid = self:addHeader(pkg)
            self:addFields(pid, pkg)
            self:addFiles(pid, apk, pkg)
        else
            self:log(string.format("Could not find pkg: %s/%s/%s/%s-%s", branch, pkg.repo, pkg.arch, pkg.name, pkg.version))
        end
    end
end

function import:addHeader(pkg)
    local sql = [[ insert into 'packages' ("name", "version", "description", "url",
        "license", "arch", "branch", "repo", "checksum", "size", "installed_size", "origin",
        "maintainer", "build_time", "commit") values(:name, :version, :description,
        :url, :license, :arch, :branch, :repo, :checksum, :size, :installed_size, :origin,
        :maintainer, :build_time, :commit)]]
    local stmt = self.db:prepare(string.format(sql))
    stmt:bind_names(pkg)
    stmt:step()
    local pid = stmt:last_insert_rowid()
    stmt:finalize()
    return pid
end

function import:formatMaintainer(maintainer)
    if maintainer then
        local name, email = utils.parse_email_addr(maintainer)
        if email then
            return { name = name, email = email }
        end
    end
end

function import:addMaintainer(maintainer)
    local m = self:formatMaintainer(maintainer)
    if m then
        local sql = [[ insert or replace into maintainer ('id', 'name', 'email')
            VALUES ((SELECT id FROM maintainer WHERE name = :name AND email = :email),
            :name, :email) ]]
        local stmt = self.db:prepare(sql)
        stmt:bind_names(m)
        stmt:step()
        local r = stmt:last_insert_rowid()
        stmt:reset()
        stmt:finalize()
        return r
    end
end

function import:delPackages(branch, del)
    local sql = [[ delete FROM 'packages' WHERE "branch" = :branch
        AND "repo" = :repo AND "arch" = :arch AND "name" = :name
        AND "version" = :version ]]
    local stmt = self.db:prepare(sql)
    for _,pkg in pairs(del) do
        self:log(string.format("Deleting: %s/%s/%s/%s-%s", branch, pkg.repo, pkg.arch, pkg.name, pkg.version))
        stmt:bind_names(pkg)
        stmt:step()
        stmt:reset()
    end
    stmt:finalize()
end

function import:formatField(v)
    local r = {}
    for _,o in ipairs({">=","<=","><","=",">","<"}) do
        if v:match(o) then
            r.name,r.version = v:match("^(.*)"..o.."(.*)$")
            r.operator = o
            return r
        end
    end
    r.name = v
    return r
end

function import:addFields(pid, pkg)
    for _,field in ipairs(conf.db.fields) do
        local values = pkg[field] or {}
        --insert pkg name as a provides in the table.
        if field == "provides" then table.insert(values, pkg.name) end
        local sql = [[ insert into '%s' ("pid", "name", "version", "operator")
            VALUES (:pid, :name, :version, :operator) ]]
        local stmt = self.db:prepare(string.format(sql, field))
        for _,v in pairs(values) do
            local r = self:formatField(v)
            r.pid = pid
            stmt:bind_names(r)
            stmt:step()
            stmt:reset()
        end
        stmt:finalize()
    end
end

function import:getFilelist(apk)
    local r = {}
    local f = io.popen(string.format("tar ztf '%s'", apk))
    for line in f:lines() do
        if not (line:match("^%.") or line:match("/$")) then
            local path,file = self:formatFile(line)
            table.insert(r, {path=path,file=file})
        end
    end
    f:close()
    return r
end

function import:addFiles(pid, apk, pkg)
    local files = self:getFilelist(apk)
    local sql = [[ insert into 'files' ("file", "path", "pkgname", "pid")
        VALUES (:file, :path, :pkgname, :pid) ]]
    local stmt = self.db:prepare(sql)
    for _,file in pairs(files) do
        file.pkgname = pkg.name
        file.pid = pid
        stmt:bind_names(file)
        stmt:step()
        stmt:reset()
    end
    stmt:finalize()
end

function import:formatFile(line)
    local path, file
    if line:match("/") then
        path, file = line:match("(.*/)(.*)")
        if path:match("/$") then path = path:sub(1, -2) end
        return "/"..path,file
    end
    return "/", line
end

function import:run()
    for _,branch in pairs(conf.branches) do
        for _,repo in pairs(conf.repos) do
            for _,arch in pairs(conf.archs) do
                local index = string.format("%s/%s/%s/%s/APKINDEX.tar.gz",
                    conf.mirror, branch, repo, arch)
                if self:fileExists(index) then
                    local version = self:repoUpdated(branch, repo, arch)
                    if version then
                        self:log(string.format("Updating: %s/%s/%s",branch, repo, arch))
                        local add,del = self:getChanges(branch, repo, arch)
                        self.db:exec("begin transaction")
                        self:addPackages(branch, add)
                        self:delPackages(branch, del)
                        self.db:exec("commit")
                        self:updateLocalRepoVersion(branch, repo, arch, version)
                        cntrl:clearCache()
                    end
                end
            end
        end
    end
    self:log("Update finished.")
end

local import = import()
import:run()
import:finalize()
