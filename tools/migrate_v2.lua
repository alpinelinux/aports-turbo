#!/usr/bin/luajit

local sqlite = require("lsqlite3")
local gver = require("gversion")

local pre_suffixes = {'alpha', 'beta', 'pre', 'rc'}
gver.set_suffixes(pre_suffixes, {'cvs', 'svn', 'git', 'hg', 'p'})

local conf = require("config")

local original_db = "db/aports.db"
local flagged_db = "db/flagged.db"

local db = sqlite.open(original_db)
local fdb = sqlite.open(flagged_db)

fdb:exec([[
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

fdb:close()

db:exec(("ATTACH DATABASE %q as new"):format(flagged_db))

db:exec(([[
    INSERT INTO new.flagged (
        origin, version, repo, created, reporter, new_version, message
    )
    SELECT packages.origin, packages.version, packages.repo, flagged.created,
    flagged.reporter, flagged.new_version, flagged.message
    FROM flagged
    JOIN packages ON flagged.fid = packages.fid
    GROUP BY packages.origin
]]))


-- check if current version in default arch (which is the most up to date)
-- is higher then the flagged version and update flagged entry if true.
local sql = ([[
    SELECT f.repo as repo, f.origin as origin, f.version as fversion,
    p.build_time as build_time, p.version as pversion
    FROM new.flagged f
    JOIN packages p
    ON p.origin = f.origin
    AND p.repo = f.repo
    WHERE p.arch = %q
    AND p.branch = %q
    GROUP BY p.origin
]]):format(conf.default.arch, conf.default.branch)

db:exec("begin")
for row in db:nrows(sql) do
    -- we need to normalize as some pkgs in aports are not following
    -- gentoo versioning.
    local pversion = gver(gver.normalize(row.pversion))
    local fversion = gver(gver.normalize(row.fversion))
    if pversion and fversion and pversion > fversion then
        db:exec(([[
            UPDATE new.flagged SET updated = %q
            WHERE repo = %q
            AND origin = %q
            AND version = %q
        ]]):format(row.build_time, row.repo, row.origin, row.fversion))
    end
end
db:exec("commit")
db:close()
