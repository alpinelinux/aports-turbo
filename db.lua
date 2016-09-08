local sqlite3   = require('lsqlite3')

local conf      = require('config')
local model     = require('model')


local db = class('db')

function db:open()
    self.db = sqlite3.open(conf.db.path)
end

function db:close()
    self.db:close()
end

function db:getDistinct(tbl,col)
    local r = {}
    local sql = string.format("SELECT DISTINCT %s from %s", col, tbl)
    for row in self.db:urows(sql) do
        table.insert(r,row)
    end
    return r
end

----
-- format database where arguments
-- by default we only set fields for packages table
-- type will set specific tables and arguments
function db:formatArgs(args, type)
    local r = {}
    r.packages = {}
    for _,v in pairs(model:packageFormat()) do
        r.packages[v] = args[v]
    end
    if type == "packages" then
        r.packages.name = args.name
        r.packages.maintainer = nil
        r.maintainer = {}
        r.maintainer.name = args.maintainer
    elseif type == "contents" then
        r.files = {}
        r.files.file = args.file
        r.files.path = args.path
        r.files.pkgname = args.name
    end
    return r
end

----
-- exclude all queries and page arguments
-- create a glob
----
function db:whereQuery(args, type, extra)
    local r,bind = {},{}
    for tn,v in pairs(self:formatArgs(args, type)) do
        for fn,v in pairs(v) do
            if (v ~= "all") and (v  ~= "") then
                local tf = string.format("%s.%s", tn, fn)
                local tb = string.format("%s_%s", tn, fn)
                table.insert(r, string.format("%s GLOB :%s", tf, tb))
                bind[tb] = v
            end
        end
    end
    if extra then table.insert(r, extra) end
    local query = next(r) and string.format("WHERE %s", table.concat(r, " AND ")) or ""
    return query,bind
end


function db:getPackages(args, offset)
    local where,bind = self:whereQuery(args, "packages")
    local r = {}
    local sql = string.format([[
        SELECT packages.*, datetime(packages.build_time, 'unixepoch') as build_time,
        maintainer.name as mname, maintainer.email as memail,
        datetime(flagged.created, 'unixepoch') as flagged FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        LEFT JOIN flagged ON packages.fid = flagged.fid
        %s
        ORDER BY packages.build_time DESC LIMIT 50 OFFSET %s]], where, offset)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    for row in stmt:nrows(sql) do
        table.insert(r, row)
    end
    stmt:finalize()
    return r
end

function db:countPackages(args)
    local where,bind = self:whereQuery(args, "packages")
    local sql = string.format([[ SELECT count(*) as qty FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        %s ]], where)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_value(0) or 0
    stmt:finalize()
    return r
end

function db:getPackage(args)
    -- temp fix for exact lookup of pacakge
    args.exact = "on"
    local where,bind = self:whereQuery(args, "packages")
    local sql = string.format([[
        SELECT packages.*, datetime(packages.build_time, 'unixepoch') as build_time,
        maintainer.name as mname, maintainer.email as memail,
        datetime(flagged.created, 'unixepoch') as flagged FROM packages
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        LEFT JOIN flagged ON packages.fid = flagged.fid
        %s ]], where)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_named_values() or {}
    stmt:finalize()
    return r
end

----
-- these queries are very similar. maybe simplefy/merge them.
----

function db:getDepends(pkg)
    local r = {}
    local sql = [[ SELECT DISTINCT packages.* FROM depends
        LEFT JOIN provides ON depends.name = provides.name
        LEFT JOIN packages ON provides.pid = packages.id
        WHERE packages.branch = :branch  AND packages.arch = :arch AND depends.pid = :id
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_names(pkg)
    for row in stmt:nrows(sql) do
        if row.name ~= pkg.name then
            table.insert(r,row)
        end
    end
    stmt:finalize()
    return r
end

function db:getProvides(pkg)
    local r = {}
    local sql = [[ SELECT DISTINCT packages.* FROM provides
        LEFT JOIN depends ON provides.name = depends.name
        LEFT JOIN packages ON depends.pid = packages.id
        WHERE packages.branch = :branch  AND packages.arch = :arch AND provides.pid = :id
    ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_names(pkg)
    for row in stmt:nrows(sql) do
        if row.name ~= pkg.name then
            table.insert(r,row)
        end
    end
    stmt:finalize()
    return r
end

function db:getOrigins(pkg)
    local r = {}
    local sql = [[ SELECT DISTINCT packages.* FROM packages
    WHERE branch = :branch AND repo = :repo AND arch = :arch AND origin = :origin ]]
    local stmt = self.db:prepare(sql)
    stmt:bind_names(pkg)
    for row in stmt:nrows(sql) do
        if row.name ~= pkg.name then
            table.insert(r,row)
        end
    end
    stmt:finalize()
    return r
end

function db:getContents(args, offset)
    local r = {}
    local where,bind = self:whereQuery(args, "contents")
    local sql = string.format([[
        SELECT files.*, packages.branch, packages.repo,
        packages.arch, packages.name FROM files
        LEFT JOIN packages ON files.pid = packages.id
        %s
        ORDER BY files.id DESC LIMIT 50 OFFSET %s ]], where, offset)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    for row in stmt:nrows(sql) do
        table.insert(r,row)
    end
    stmt:finalize()
    return r
end

function db:countContents(args)
    local where,bind = self:whereQuery(args, "contents")
    local sql = string.format([[ SELECT count(file) as qty FROM files
    LEFT JOIN packages ON files.pid = packages.id %s]], where)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_value(0) or 0
    stmt:finalize()
    return r
end

function db:getFlagged(args, offset)
    local r = {}
    local extra = "packages.name = packages.origin AND packages.fid IS NOT NULL"
    local where,bind = self:whereQuery(args, "packages", extra)
    local sql = string.format([[
        SELECT packages.origin, packages.version, packages.branch, packages.repo, flagged.new_version,
        datetime(flagged.created, 'unixepoch') as created,
        flagged.message, maintainer.name as mname
        FROM packages
        LEFT JOIN flagged ON packages.fid = flagged.fid
        LEFT JOIN maintainer ON packages.maintainer = maintainer.id
        %s
        GROUP BY packages.origin, packages.branch
        ORDER BY flagged.created DESC LIMIT 50 OFFSET %s
    ]], where, offset)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    for row in stmt:nrows(sql) do
        table.insert(r,row)
    end
    stmt:finalize()
    return r
end

-- will not close when not results are found
function db:countFlagged(args)
    local extra = "packages.name = packages.origin AND packages.fid IS NOT NULL"
    local where,bind = self:whereQuery(args, "packages", extra)
    local sql = string.format([[ SELECT count(*) as qty FROM packages %s ]], where)
    local stmt = self.db:prepare(sql)
    stmt:bind_names(bind)
    local r = (stmt:step()==sqlite3.ROW) and stmt:get_value(0) or 0
    stmt:finalize()
    return r
end

function db:flagOrigin(args, pkg)
    local sql = [[ INSERT INTO flagged (created, reporter, new_version, message)
        VALUES (strftime('%s', 'now'), :from, :new_version, :message)]]
    self.db:exec("BEGIN")
    local stmt = self.db:prepare(sql)
    stmt:bind_names(args)
    stmt:step()
    local fid = stmt:last_insert_rowid()
    stmt:finalize()
    if fid then
        self.db:exec(
            string.format([[
                UPDATE packages SET fid = '%s'
                WHERE branch = '%s' AND repo = '%s' AND origin = '%s'
                AND version = '%s' ]], fid, pkg.branch, pkg.repo, pkg.origin,
                pkg.version
            )
        )
        self.db:exec("COMMIT")
        return fid
    end
end

return db
