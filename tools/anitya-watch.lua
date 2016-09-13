#!/usr/bin/env luajit
---------
-- This script connects to fedmsg/zeromq interface of Anitya
-- <https://release-monitoring.org> and flags packages in the edge branch
-- for which a new version is released. It should be run as a daemon. Before
-- first run or after an outage run anitya-check-all to check all packages.
--
-- ## How does it work
--
-- Anitya watches registered projects and when a new release is found, then it
-- sends a message via fedmsg. This scripts consumes these messages. If the
-- updated project contains mapping for the configured distro, then it takes
-- distro's package name and new version from the message. Then looks into the
-- aports database; if there's an older version that is not flagged yet, or the
-- flag contains older new version, then it flags the package and sends email
-- to its maintainer.
--

local log     = require 'turbo.log'
local escape  = require 'turbo.escape'
local zmq     = require 'lzmq'
local zpoller = require 'lzmq.poller'

local aports  = require 'anitya_aports'
local conf    = require 'config'
local utils   = require 'utils'

local get = utils.get
local distro = conf.anitya.distro
local json_decode = escape.json_decode


--- Receives multipart message and returns decoded JSON payload.
local function receive_json_msg(sock)
    local resp, err = sock:recv_multipart()
    if err then
        return nil, err
    end
    log.debug('Received message from topic '..resp[1])

    local ok, res = pcall(json_decode, resp[2])
    if not ok then
        return nil, 'Failed to parse message as JSON: '..res
    end

    return res
end

--- Handles message from topic `anitya.project.map.new`; if it's mapping for
-- our distro, then flags the package if it's outdated.
local function handle_map_new(msg)
    if get(msg, 'distro.name') ~= distro then
        return nil
    end

    local pkgname = get(msg, 'message.new')
    local version = get(msg, 'project.version')

    if pkgname and version then
        log.notice(("Received version update: %s %s"):format(pkgname, version))
        aports.flag_outdated_pkgs(pkgname, version)
    end
end

--- Handles message from topic `anitya.project.version.update`; if the project
-- contains mapping for our distro, then flags the package if it's outdated.
local function handle_version_update(msg)
    local pkgname = nil
    for _, pkg in ipairs(get(msg, 'message.packages') or {}) do
        if pkg.distro == distro then
            pkgname = pkg.package_name
            break
        end
    end
    local version = get(msg, 'message.upstream_version')

    if pkgname and version then
        log.notice(("Received version update: %s %s"):format(pkgname, version))
        aports.flag_outdated_pkgs(pkgname, version)
    end
end


--------  M a i n  --------

local sock, err = zmq.context():socket(zmq.SUB, {
    connect = conf.anitya.fedmsg_uri
})
zmq.assert(sock, err)

local handlers = {
    ['org.release-monitoring.prod.anitya.project.version.update'] = handle_version_update,
    ['org.release-monitoring.prod.anitya.project.map.new'] = handle_map_new,
}
for topic, _ in pairs(handlers) do
    sock:subscribe(topic)
end

local poller = zpoller.new(1)
poller:add(sock, zmq.POLLIN, function()
    local payload, err = receive_json_msg(sock)
    if err then
        log.error('Failed to receive message from fedmsg: '..err)
    end
    local ok, err = pcall(handlers[payload.topic], payload.msg)
    if not ok then
        log.error(err)
    end
end)

log.notice('Connecting to '..conf.anitya.fedmsg_uri)
poller:start()
