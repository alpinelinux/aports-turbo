local gversion = require("gversion")
local log      = require("turbo.log")

local conf     = require("config")
local db       = require("db")
local cntrl    = require("controller")

local format = string.format
local normalize_version = gversion.normalize
local parse_version = gversion.parse
local branch = conf.default.branch

local pre_suffixes = {'alpha', 'beta', 'pre', 'rc'}
gversion.set_suffixes(pre_suffixes, {'cvs', 'svn', 'git', 'hg', 'p'})

--- Flags `pkg` as outdated and send email to its maintainer.
--
-- @tparam table pkg The package table as from `db:getPackage`.
-- @tparam string new_version
local function flag_package(pkg, new_version)
    local flag_fields = {
        from = conf.mail.from,
        new_version = new_version,
        message = conf.anitya.flag_message
    }
    db:open()
    assert(db:flagOrigin(flag_fields, pkg),
        'Failed to flag package: '..pkg.origin)
    assert(cntrl.flagMail(flag_fields, pkg),
        'Failed to send email for package: '..pkg.origin)
    db:close()
end

--- Compares the current version with new version and returns true if the
-- current version is outdated.
--
-- This function has special handling of pre-release versions. If `new_ver` is
-- higher than `curr_ver`, but contains pre-release suffix lower than the
-- `curr_ver`, then it returns false. The point is to ignore e.g. beta releases
-- unless the current version is also beta or lower (alpha).
--
-- @tparam gversion.Version curr_ver The current version.
-- @tparam gversion.Version new_ver The new version.
-- @treturn boolean
local function is_outdated(curr_ver, new_ver)
    if new_ver <= curr_ver then
        return false
    end

    local allow_pre = false
    for _, suffix in pairs(pre_suffixes) do
        if curr_ver[suffix] then
            allow_pre = true
        end
        if new_ver[suffix] then
           return allow_pre
        end
    end

    return true
end

-- get all packages with same origin and return only the row with the
-- highest version number
local function get_latest_pkg(origin)
    local res = {}
    local ldb = db.raw_db(branch)
    local stmt = ldb:prepare [[
        SELECT DISTINCT p.version, p.origin, p.repo, f.new_version,
        m.email as memail
        FROM packages p
        LEFT JOIN flagged f
        ON p.repo = f.repo AND p.origin = f.origin AND p.version = f.version
        LEFT JOIN maintainer m
        ON p.maintainer = m.id
        WHERE p.origin = ?
    ]]
    stmt:bind_values(origin)
    for row in stmt:nrows() do
        if next(res) then
            local next_ver = gversion.parse(gversion.normalize(row.version))
            local curr_ver = gversion.parse(gversion.normalize(res.version))
            res = (next_ver > curr_ver) and row or res
        else
            res = row
        end
    end
    stmt:finalize()
    ldb:close()
    return res
end

local M = {}

--- Yields names of aports (i.e. origin packages) in the specified branch.
-- If the database is not opened, then it opens it and close after finish.
function M.each_aport_name()
    local ldb = db.raw_db(branch)
    local sql = [[
        SELECT DISTINCT origin
        FROM packages
    ]]

    return coroutine.wrap(function()
        for name in ldb:urows(sql) do
            coroutine.yield(name)
        end
        if ldb:isopen() then ldb:close() end
    end)
end

function M.flag_outdated_pkgs(origin, new_ver)
    new_ver = assert(parse_version(normalize_version(new_ver)),
        'Malformed new version: '..new_ver)
    local pkg = get_latest_pkg(origin)
    if next(pkg) then
        local curr_ver = parse_version(pkg.version)
        if not curr_ver then error('Malformed current version: '..pkg.version) end
        local flag_ver = parse_version(normalize_version(pkg.new_version or ''))
        if (not flag_ver or new_ver > flag_ver) and is_outdated(curr_ver, new_ver) then
            log.notice(format('Flagging package %s-%s, new version is %s',
                origin, curr_ver, new_ver))
            local ok, err = pcall(flag_package, pkg, tostring(new_ver))
            if not ok then error(err, 2) end
        end
    end
end

return M
