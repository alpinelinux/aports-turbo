#!/usr/bin/env luajit
---------
-- This script checks versions of all packages in the edge branch on Anitya
-- <https://release-monitoring.org/> and flags outdated packages. It should
-- be run for the first check or after outages. For periodic checks use
-- anitya-watch.
--
-- ## How does it work
--
-- It iterates over abuild names (i.e. origin packages) in the edge branch and
-- requests Anitya's resource `GET /project/{distro}/{pkgname}` for each
-- pkgname and the configured distro. If a project with the distro's mapping
-- is found, then it takes version of the latest release from the response.
-- Then looks into the aports database; if there's an older version that is not
-- flagged yet, or the flag contains older new version, then it flags the
-- package and sends email to its maintainer.
--

TURBO_SSL = true
__TURBO_USE_LUASOCKET__ = false

local _      = require 'turbo'
local async  = require 'turbo.async'
local escape = require 'turbo.escape'
local log    = require 'turbo.log'

local aports = require 'anitya_aports'
local cc     = require 'concurrent'
local conf   = require 'config'

local HTTPClient = async.HTTPClient
local json_decode = escape.json_decode
local yield = coroutine.yield

local anitya_distro_pkg_uri = ("%s/project/%s/%s"):format(
    conf.anitya.api_uri, conf.anitya.distro, '%s')


--- Gets project from Anitya by the given distro's package name and returns
-- response as a table.
local function fetch_distro_pkg(pkgname)
    local url = anitya_distro_pkg_uri:format(pkgname)
    local res = yield(HTTPClient():fetch(url))

    if res.error then
        error(res.error)
    elseif res.code == 200 then
        return json_decode(res.body)
    end
end


--------  M a i n  --------

log.notice 'Checking outdated packages using Anitya...'

cc.foreach(aports.each_aport_name(), function(pkgname)
    local proj = fetch_distro_pkg(pkgname)

    if proj and proj.stable_versions and proj.stable_versions[1] then
        log.debug(("Found %s %s"):format(pkgname, proj.stable_versions[1]))
        aports.flag_outdated_pkgs(pkgname, proj.stable_versions[1])
    else
        log.debug('Did not find '..pkgname)
    end
end, conf.anitya.api_concurrency)

log.success 'Completed'
