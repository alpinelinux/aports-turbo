#!/usr/bin/env luajit

local sqlite    = require("lsqlite3")

local conf      = require("config")
local utils     = require("utils")

local db

local function log(msg)
    if conf.logging then
        print(msg)
    end
end

local function sql_debug(fname, sql)
    if conf.db.debug == true then
        print(("Function: %s \nDatabase error: %s \nSQL Query:\n%s"):format(
            fname, db:errmsg(), sql))
    end
end

local function create_tables()
    if conf.db.init ~= true then return true end
    -- packages
    db:exec([[
        CREATE TABLE IF NOT EXISTS 'packages' (
            'id' INTEGER PRIMARY KEY,
            'name' TEXT,
            'version' TEXT,
            'description' TEXT,
            'url' TEXT,
            'license' TEXT,
            'arch' TEXT,
            'repo' TEXT,
            'checksum' TEXT,
            'size' INTEGER,
            'installed_size' INTEGER,
            'origin' TEXT,
            'maintainer' INTEGER,
            'build_time' INTEGER,
            'commit' TEXT,
            'provider_priority' INTEGER,
            'fid' INTEGER
        )
    ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_name' on 'packages' (name) ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_maintainer' on 'packages' (maintainer) ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_build_time' on 'packages' (build_time) ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'packages_origin' on 'packages' (origin) ]])
    -- files
    db:exec([[
        CREATE TABLE IF NOT EXISTS 'files' (
            'id' INTEGER PRIMARY KEY,
            'file' TEXT,
            'path' TEXT,
            'pid' INTEGER REFERENCES packages(id) ON DELETE CASCADE
        )
    ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'files_file' on 'files' (file) ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'files_path' on 'files' (path) ]])
    db:exec([[ CREATE INDEX IF NOT EXISTS 'files_pid' on 'files' (pid) ]])
    -- provides, depends, install_if
    local field = [[
        CREATE TABLE IF NOT EXISTS '%s' (
            'name' TEXT,
            'version' TEXT,
            'operator' TEXT,
            'pid' INTEGER REFERENCES packages(id) ON DELETE CASCADE
        )
    ]]
    for _,v in pairs(conf.db.fields) do
        db:exec((field):format(v))
        db:exec(([[CREATE INDEX IF NOT EXISTS '%s_name' on %q (name)]]):format(v, v))
        db:exec(([[CREATE INDEX IF NOT EXISTS '%s_pid' on %q (pid)]]):format(v, v))
    end
    -- maintainers
    db:exec([[
        CREATE TABLE IF NOT EXISTS maintainer (
            'id' INTEGER PRIMARY KEY,
            'name' TEXT,
            'email' TEXT
        )
    ]])
    db:exec([[CREATE INDEX IF NOT EXISTS 'maintainer_name' on maintainer (name) ]])
    -- repoversion
    db:exec([[
        CREATE TABLE IF NOT EXISTS 'repoversion' (
            'repo' TEXT,
            'arch' TEXT,
            'version' TEXT,
            PRIMARY KEY ('repo', 'arch')
        ) WITHOUT ROWID
    ]])
end

local function create_flagged_table()
    if conf.db.init ~= true then return true end
    db:exec([[
        CREATE TABLE IF NOT EXISTS 'flagged' (
            'origin' TEXT,
            'version' TEXT,
            'repo' TEXT,
            'created' INTEGER,
            'updated' INTEGER,
            'reporter' TEXT,
            'new_version' TEXT,
            'message' TEXT,
            PRIMARY KEY ('origin', 'version', 'repo')
        ) WITHOUT ROWID
    ]])
end

---
-- get the current git describe from DESCRIPTION file
---
local function get_repo_version(branch, repo, arch)
    local res = {}
    local index = ("%s/%s/%s/%s/APKINDEX.tar.gz"):format(conf.mirror, branch, repo, arch)
    local f = io.popen(("tar -Ozx -f '%s' DESCRIPTION"):format(index))
    for line in f:lines() do
        table.insert(res, line)
    end
    f:close()
    if next(res) then return res[1] end
end

local function get_local_repo_version(repo, arch)
    local sql = [[
        SELECT version
        FROM repoversion
        WHERE repo = ?
        AND arch = ?
    ]]
    local stmt = db:prepare(sql)
    stmt:bind_values(repo, arch)
    local r = (stmt:step() == sqlite.ROW) and stmt:get_value(0) or false
    stmt:finalize()
    return r
end

local function update_local_repo_version(repo, arch, version)
    local sql = [[
        INSERT OR REPLACE INTO repoversion (
            'version', 'repo', 'arch'
        )
        VALUES (
            :version, :repo, :arch
        )
    ]]
    local stmt = db:prepare(sql)
    stmt:bind_values(version, repo, arch)
    stmt:step()
    stmt:finalize()
end

---
-- compare remote repo version with local and return remote version if updated
---
local function repo_updated(branch, repo, arch)
    local v = get_repo_version(branch, repo, arch)
    local l = get_local_repo_version(repo, arch)
    if (v ~= l) then return v end
end

local function get_apk_index(branch, repo, arch)
    local r,i = {},{}
    local index = ("%s/%s/%s/%s/APKINDEX.tar.gz"):format(conf.mirror, branch, repo, arch)
    local f = io.popen(("tar -Ozx -f %q APKINDEX"):format(index))
    for line in f:lines() do
        if (line ~= "") then
            local k,v = line:match("^(%a):(.*)")
            local key = conf.index.fields[k]
            if key then
                r[key] = k:match("^[Dpi]$") and utils.split(v, "%S+") or v
            end
        else
            local nv = ("%s-%s"):format(r.name, r.version)
            r.repo = repo
            r.branch = branch
            i[nv] = r
            r = {}
        end
    end
    f:close()
    return i
end

local function get_changes(branch, repo, arch)
    local del = {}
    local add = get_apk_index(branch, repo, arch)
    local sql = [[
        SELECT repo, arch, name, version, origin
        FROM packages
        WHERE repo = :repo
        AND arch = :arch
    ]]
    local stmt = db:prepare(sql)
    sql_debug("get_changes", sql)
    stmt:bind_values(repo, arch)
    for r in stmt:nrows() do
        local nv = ("%s-%s"):format(r.name, r.version)
        if add[nv] then
            add[nv] = nil
        else
            del[nv] = r
        end
    end
    stmt:finalize()
    return add,del
end

local function format_maintainer(maintainer)
    if maintainer then
        local name, email = utils.parse_email_addr(maintainer)
        if email then
            return { name = name, email = email }
        end
    end
end

local function add_maintainer(maintainer)
    local m = format_maintainer(maintainer)
    if m then
        local sql = [[
            INSERT OR REPLACE INTO maintainer ('id', 'name', 'email')
            VALUES (
                (SELECT id FROM maintainer WHERE name = :name AND email = :email),
                :name,
                :email
            )
        ]]
        local stmt = db:prepare(sql)
        sql_debug("add_maintainer", sql)
        stmt:bind_names(m)
        stmt:step()
        local r = stmt:last_insert_rowid()
        stmt:reset()
        stmt:finalize()
        return r
    end
end

local function add_header(pkg)
    local sql = [[
        INSERT INTO 'packages' (
            "name", "version", "description", "url", "license", "arch", "repo",
            "checksum", "size", "installed_size", "origin", "maintainer",
            "build_time", "commit", "provider_priority"
        )
        VALUES (
            :name, :version, :description, :url, :license, :arch, :repo,
            :checksum, :size, :installed_size, :origin, :maintainer,
            :build_time, :commit, :provider_priority
        )
    ]]
    local stmt = db:prepare(sql)
    sql_debug("add_header", sql)
    stmt:bind_names(pkg)
    stmt:step()
    local pid = stmt:last_insert_rowid()
    stmt:finalize()
    return pid
end

local function format_field(v)
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

local function add_fields(pid, pkg)
    for _,field in ipairs(conf.db.fields) do
        local values = pkg[field] or {}
        --insert pkg name as a provides in the table.
        if field == "provides" then table.insert(values, pkg.name) end
        local sql = [[
            INSERT INTO '%s' (
                "pid", "name", "version", "operator"
            )
            VALUES (
                :pid, :name, :version, :operator
            )
        ]]
        local stmt = db:prepare((sql):format(field))
        for _,v in pairs(values) do
            local r = format_field(v)
            r.pid = pid
            stmt:bind_names(r)
            stmt:step()
            stmt:reset()
        end
        stmt:finalize()
    end
end

local function format_file(line)
    local path, file
    if line:match("/") then
        path, file = line:match("(.*/)(.*)")
        if path:match("/$") then path = path:sub(1, -2) end
        return "/"..path,file
    end
    return "/", line
end

local function get_file_list(apk)
    local r = {}
    local f = io.popen(("tar ztf %q"):format(apk))
    for line in f:lines() do
        if not (line:match("^%.") or line:match("/$")) then
            local path,file = format_file(line)
            table.insert(r, {path=path,file=file})
        end
    end
    f:close()
    return r
end

local function add_files(pid, apk, pkg)
    local files = get_file_list(apk)
    local sql = [[
        INSERT INTO 'files' (
            "file", "path", "pid"
        )
        VALUES (
            :file, :path, :pid
        )
    ]]
    local stmt = db:prepare(sql)
    sql_debug("add_files", sql)
    for _,file in pairs(files) do
        file.pkgname = pkg.name
        file.pid = pid
        stmt:bind_names(file)
        stmt:step()
        stmt:reset()
    end
    stmt:finalize()
end

local function add_packages(branch, add)
    for _,pkg in pairs(add) do
        local apk = ("%s/%s/%s/%s/%s-%s.apk"):format(conf.mirror, branch,
            pkg.repo, pkg.arch, pkg.name, pkg.version)
        if utils.file_exists(apk) then
            log(("Adding: %s/%s/%s/%s-%s"):format(branch, pkg.repo, pkg.arch,
                pkg.name, pkg.version))
            pkg.maintainer = add_maintainer(pkg.maintainer)
            local pid = add_header(pkg)
            add_fields(pid, pkg)
            add_files(pid, apk, pkg)
        else
            log(("Could not find pkg: %s/%s/%s/%s-%s"):format(branch, pkg.repo,
                pkg.arch, pkg.name, pkg.version))
        end
    end
end

--- Removes maintainers that don't maintain any package.
local function clean_maintainers()
    local sql = [[
        DELETE FROM 'maintainer'
        WHERE id NOT IN (SELECT maintainer FROM 'packages')
    ]]
    local stmt = db:prepare(sql)
    sql_debug("clean_maintainers", sql)
    stmt:step()
    stmt:finalize()
end

local function del_packages(branch, del)
    local sql = [[
        DELETE FROM 'packages'
        WHERE "repo" = :repo
        AND "arch" = :arch
        AND "name" = :name
        AND "version" = :version
    ]]
    local stmt = db:prepare(sql)
    sql_debug("del_packages", sql)
    for _,pkg in pairs(del) do
        log(("Deleting: %s/%s/%s/%s-%s"):format(branch, pkg.repo, pkg.arch,
            pkg.name, pkg.version))
        stmt:bind_names(pkg)
        stmt:step()
        stmt:reset()
    end
    stmt:finalize()
end

local function update_flagged(unflag)
    local sql = [[
        UPDATE flagged SET updated = strftime('%s', 'now')
        WHERE repo = :repo
        AND origin = :origin
        AND version = :version
    ]]
    local stmt = db:prepare(sql)
    sql_debug("update_flagged", sql)
    for _,v in pairs(unflag) do
        stmt:bind_names(v)
        stmt:step()
        stmt:reset()
        if db:changes() > 0 then
            log(("Unflagging: %s/%s/%s"):format(v.repo, v.origin, v.version))
        end
    end
    stmt:finalize()
end

local function update(branch, repo, arch)
    local index = ("%s/%s/%s/%s/APKINDEX.tar.gz"):format(conf.mirror, branch, repo, arch)
    local res = {}
    if utils.file_exists(index) then
        local version = repo_updated(branch, repo, arch)
        if version then
            log(("Updating: %s/%s/%s"):format(branch, repo, arch))
            local add,del = get_changes(branch, repo, arch)
            add_packages(branch, add)
            del_packages(branch, del)
            clean_maintainers()
            update_local_repo_version(repo, arch, version)
            res = del
        else
            log(("Skipping: %s/%s/%s"):format(branch, repo, arch))
        end
    end
    return res
end

----------------
----- MAIN -----
----------------
local unflag = {}
for _,branch in pairs(conf.branches) do
    local db_file = ("%s/aports-%s.db"):format(conf.db.path, branch)
    db = sqlite.open(db_file)
    create_tables()
    db:exec("PRAGMA foreign_keys=ON")
    db:exec("PRAGMA journal_mode=WAL")
    db:exec("begin")
    for _,repo in pairs(conf.repos) do
        for _,arch in pairs(conf.archs) do
            local del = update(branch, repo, arch)
            if branch == conf.default.branch then
                for _,v in pairs(del) do
                    local k = ("%s-%s-%s"):format(v.repo, v.origin, v.version)
                    unflag[k] = {repo=v.repo, origin=v.origin, version=v.version}
                end
            end
        end
    end
    if branch == conf.default.branch then
        create_flagged_table()
        update_flagged(unflag)
    end
    db:exec("commit")
    db:exec("PRAGMA wal_checkpoint(TRUNCATE)")
    db:close()
end
log("Update finished.")
