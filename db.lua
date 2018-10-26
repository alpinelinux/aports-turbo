local sqlite3   = require('lsqlite3')

local conf      = require('config')
local utils     = require("utils")

local db = {}

function db:open()
    self.dbs = {}
    for _,branch in pairs(conf.branches) do
        local db_filename = ("aports-%s.db"):format(branch)
        local db_path = ("%s/%s"):format(conf.db.path, db_filename)
        self.dbs[branch] = sqlite3.open(db_path)
    end
end

function db:select(branch)
    branch = utils.in_table(branch, conf.branches) and branch or conf.default.branch
    self.db = self.dbs[branch]
end

function db:close()
    for _,dbh in pairs(self.dbs) do
        if dbh:isopen() then dbh:close() end
    end
end

function db:debug(fname, sql, fields)
    local ft = "None"
    if conf.db.debug == true then
        if type(fields) == "table" and next(fields) then
            ft = "\n"
            for k,v in pairs(fields) do
                ft = ft..("%-20s = %s\n"):format(k,v)
            end
        end
        print(("Function: %s\nDatabase error: %s\nSQL Query:\n%s\nFields: %s"):format(
            fname, self.db:errmsg(), sql, ft))
    end
end

function db.raw_db(branch)
    local db_filename = ("aports-%s.db"):format(branch)
    local db_path = ("%s/%s"):format(conf.db.path, db_filename)
    local dbh = sqlite3.open(db_path)
    return dbh
end

function db:getDistinct(tbl,col)
    local r = {}
    local sql = string.format("SELECT DISTINCT %s from %s", col, tbl)
    self:debug("getDistinct", sql)
    for row in self.db:urows(sql) do
        table.insert(r,row)
    end
    return r
end

----
-- format database where arguments
-- by default we only set fields for packages table
-- type will set specific tables and arguments
local function format_args(args, type)
    local r = {}
    r.packages = {}
    for _,v in pairs(conf.index.fields) do
        r.packages[v] = args[v]
    end
    if type == "packages" then
        r.packages.repo = args.repo
        r.packages.maintainer = nil
        r.maintainer = {}
        r.maintainer.name = args.maintainer
    elseif type == "contents" then
        r.files = {}
        r.files.file = args.file
        r.files.path = args.path
        r.packages.repo = args.repo
    end
    return r
end

----
-- exclude all queries and page arguments
-- create a glob
----
local function where_query(args, type, extra)
    args = utils.copy_table(args, {"branch"})
    local r,bind = {},{}
    for tn,v in pairs(format_args(args, type)) do
        for fn,w in pairs(v) do
            if w == "None" then
                table.insert(r, ("%s.%s IS NULL"):format(tn, fn))
            elseif (w ~= "all") and (w  ~= "") then
                local tf = ("%s.%s"):format(tn, fn)
                local tb = ("%s_%s"):format(tn, fn)
                table.insert(r, ("%s GLOB :%s"):format(tf, tb))
                bind[tb] = w
            end
        end
    end
    if extra then table.insert(r, extra) end
    local query = next(r) and string.format("WHERE %s", table.concat(r, " AND ")) or ""
    return query,bind
end

function db:getPackages(args, offset)
    local where,bind = where_query(args, "packages")
    local r = {}
    local sql1 = string.format([[
        SELECT packages.*, datetime(packages.build_time, 'unixepoch') as build_time,
        maintainer.name as mname, maintainer.email as memail,
        datetime(flagged.created, 'unixepoch') as flagged
        FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        LEFT JOIN flagged ON packages.origin = flagged.origin AND
        packages.version = flagged.version AND packages.repo = flagged.repo
        %s
        ORDER BY packages.build_time DESC
        LIMIT 50 OFFSET %s
    ]], where, offset)
    local sql2 = string.format([[
        SELECT packages.*, datetime(packages.build_time, 'unixepoch') as build_time,
        maintainer.name as mname, maintainer.email as memail
        FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        %s
        ORDER BY packages.build_time DESC
        LIMIT 50 OFFSET %s
    ]], where, offset)
    -- only get flagged status for default branch
    local sql = (args.branch == conf.default.branch) and sql1 or sql2
    local stmt = self.db:prepare(sql)
    self:debug("getPackages", sql, bind)
    stmt:bind_names(bind)
    for row in stmt:nrows(sql) do
        table.insert(r, row)
    end
    stmt:finalize()
    return r
end

function db:countPackages(args)
    local where,bind = where_query(args, "packages")
    local sql = string.format([[
        SELECT count(*) as qty FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        %s
    ]], where)
    local stmt = self.db:prepare(sql)
    self:debug("countPackages", sql, bind)
    stmt:bind_names(bind)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_value(0) or 0
    stmt:finalize()
    return r
end

function db:getPackage(branch, repo, arch, pkgname)
    local sql1 = [[
        SELECT packages.*, datetime(packages.build_time, 'unixepoch') as build_time,
        maintainer.name as mname, maintainer.email as memail,
        datetime(flagged.created, 'unixepoch') as flagged
        FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        LEFT JOIN flagged ON packages.origin = flagged.origin AND
        packages.version = flagged.version AND packages.repo = flagged.repo
        WHERE packages.repo = :repo AND packages.arch = :arch AND packages.name = :pkgname
    ]]
    local sql2 = [[
        SELECT packages.*, datetime(packages.build_time, 'unixepoch') as build_time,
        maintainer.name as mname, maintainer.email as memail
        FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        WHERE packages.repo = :repo AND packages.arch = :arch AND packages.name = :pkgname
    ]]
    -- only get flagged status for default branch
    local sql = (branch == conf.default.branch) and sql1 or sql2
    local stmt = self.db:prepare(sql)
    self:debug("getPackage", sql, {repo, arch, pkgname})
    stmt:bind_values(repo, arch, pkgname)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_named_values() or {}
    stmt:finalize()
    return r
end

function db:getDepends(pkg)
    local r = {}
    local sql = [[
        SELECT DISTINCT pa.repo, pa.arch, pa.name, MAX(pa.provider_priority)
        FROM depends de
        LEFT JOIN provides pr ON de.name = pr.name
        LEFT JOIN packages pa ON pr.pid = pa.id
        WHERE pa.arch = :arch AND de.pid = :id
        GROUP BY pr.name
        ORDER BY pa.name
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("getDepends", sql, pkg)
    stmt:bind_names(pkg)
    for row in stmt:nrows(sql) do
        if row.name ~= pkg.name then
            row.branch = pkg.branch
            table.insert(r,row)
        end
    end
    stmt:finalize()
    return r
end

function db:getProvides(pkg)
    local r = {}
    local sql = [[
        SELECT DISTINCT packages.* FROM provides
        LEFT JOIN depends ON provides.name = depends.name
        LEFT JOIN packages ON depends.pid = packages.id
        WHERE packages.arch = :arch AND provides.pid = :id
        ORDER BY packages.name
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("getProvides", sql, pkg)
    stmt:bind_names(pkg)
    for row in stmt:nrows(sql) do
        if row.name ~= pkg.name then
            row.branch = pkg.branch
            table.insert(r,row)
        end
    end
    stmt:finalize()
    return r
end

function db:getOrigins(pkg)
    local r = {}
    local sql = [[
        SELECT DISTINCT packages.* FROM packages
        WHERE repo = :repo AND arch = :arch AND origin = :origin
        ORDER BY packages.name
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("getOrigins", sql, pkg)
    stmt:bind_names(pkg)
    for row in stmt:nrows(sql) do
        if row.name ~= pkg.name then
            row.branch = pkg.branch
            table.insert(r,row)
        end
    end
    stmt:finalize()
    return r
end

function db:getContents(args, offset)
    local r = {}
    local where,bind = where_query(args, "contents")
    local sql = string.format([[
        SELECT packages.repo, packages.arch, packages.name, files.*
        FROM packages
        JOIN files ON files.pid = packages.id
        %s
        LIMIT 50 OFFSET %s
    ]], where, offset)
    self:debug("getContents", sql, bind)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    for row in stmt:nrows(sql) do
        table.insert(r,row)
    end
    stmt:finalize()
    return r
end

function db:countContents(args)
    local where,bind = where_query(args, "contents")
    local sql = string.format([[
        SELECT count(packages.id)
        FROM packages
        JOIN files ON files.pid = packages.id
        %s
    ]], where)
    local stmt = self.db:prepare(sql)
    self:debug("countContents", sql, bind)
    stmt:bind_names(bind)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_value(0) or 0
    stmt:finalize()
    return r
end

local function get_offset(rows, row, offset, cnt)
    if cnt >= offset and cnt <= (offset+50-1) then
        table.insert(rows, row)
    end
    return cnt+1
end

function db:getFlagged(args, offset)
    local r, cnt = {}, 0
    local extra = "packages.name = packages.origin AND flagged.updated IS NULL"
    local where,bind = where_query(args, "packages", extra)
    local sql = string.format([[
        SELECT packages.origin, packages.version, packages.repo,
        maintainer.name as mname, flagged.new_version, flagged.message,
        datetime(flagged.created, 'unixepoch') as created
        FROM flagged
        LEFT JOIN packages ON packages.origin = flagged.origin AND
        packages.version = flagged.version AND packages.repo = flagged.repo
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        %s
        GROUP BY packages.origin
        ORDER BY flagged.created DESC
    ]], where)
    local stmt = self.db:prepare(sql)
    self:debug("getFlagged", sql, bind)
    stmt:bind_names(bind)
    for row in stmt:nrows(sql) do
        cnt = get_offset(r, row, offset, cnt)
    end
    stmt:finalize()
    return r, cnt
end

function db:isFlagged(origin, repo, version)
    local sql = [[
        SELECT 1 FROM flagged
        WHERE origin = :origin AND repo = :repo AND version = :version
        LIMIT 1
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("isFlagged", sql, {origin, repo, version})
    stmt:bind_values(origin, repo, version)
    local r = (stmt:step()==sqlite3.ROW) and true or false
    stmt:finalize()
    return r
end

function db:isOrigin(repo, origin, version)
    local sql = [[
        SELECT 1 from packages
        WHERE repo = :repo AND origin = :origin AND version = :version
        LIMIT 1
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("isOrigin", sql, {repo, origin, version})
    stmt:bind_values(repo, origin, version)
    local r = (stmt:step()==sqlite3.ROW) and true or false
    stmt:finalize()
    return r
end

function db:getMaintainer(origin)
    local res = {}
    local sql = [[
        SELECT maintainer.*
        FROM maintainer
        JOIN packages ON maintainer.id = packages.maintainer
        WHERE origin = :origin
        GROUP BY origin
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("getMaintainer", sql, {origin})
    stmt:bind_values(origin)
    if stmt:step() == sqlite3.ROW then
        res = stmt:get_named_values()
    end
    stmt:finalize()
    if next(res) then return res end
end

function db:flagOrigin(args, pkg)
    local res = false
    self:select(conf.default.branch)
    args.origin = pkg.origin
    args.version = pkg.version
    args.repo = pkg.repo
    local sql = [[
        INSERT OR REPLACE INTO flagged (
            origin, version, repo, created, updated, reporter, new_version,
            message
        )
        VALUES (
            :origin, :version, :repo, strftime('%s', 'now'), NULL, :from,
            :new_version, :message
        )
    ]]
    local stmt = self.db:prepare(sql)
    self:debug("flagOrigin", sql, args)
    stmt:bind_names(args)
    if stmt:step() == sqlite3.DONE then res = true end
    stmt:finalize()
    return res
end

return db
