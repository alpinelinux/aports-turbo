#!/usr/bin/env luajit

TURBO_SSL   = true
__TURBO_USE_LUASOCKET__ = false

local turbo = require("turbo")

local conf  = require("config")
local cntrl = require("controller")
local utils = require("utils")

local is_valid_email = utils.is_valid_email

-- packages renderer to display a list of packages
local packagesRenderer = class("packagesRenderer", turbo.web.RequestHandler)

function packagesRenderer:get()
    local args = {
        name = self:get_argument("name", "", true),
        branch = self:get_argument("branch", conf.default.branch, true),
        arch = self:get_argument("arch", "", true),
        repo = self:get_argument("repo", "", true),
        maintainer = self:get_argument("maintainer", "", true),
        page = tonumber(self:get_argument("page", 1, true)) or 1,
    }
    if utils.in_table(args.branch, conf.branches) then
        self:write(cntrl.packages(args))
    else
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
end

-- package renderer, to display a single package
local packageRenderer = class("packageRenderer", turbo.web.RequestHandler)

function packageRenderer:get(branch, repo, arch, name)
    local pkg = cntrl.getPackage(branch, repo, arch, name)
    if next(pkg) and utils.in_table(branch, conf.branches) then
        pkg.branch = branch
        self:write(cntrl.package(pkg))
    else
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
end

local contentsRenderer = class("contentsRenderer", turbo.web.RequestHandler)

function contentsRenderer:get()
    local args = {
        file = self:get_argument("file", "", true),
        path = self:get_argument("path", "", true),
        name = self:get_argument("name", "", true),
        branch = self:get_argument("branch", conf.default.branch, true),
        repo = self:get_argument("repo", "", true),
        arch = self:get_argument("arch", "", true),
        page = tonumber(self:get_argument("page", 1, true)) or 1,
    }
    if utils.in_table(args.branch, conf.branches) then
        self:write(cntrl.contents(args))
    else
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
end

-- flagged renderer, to display the flag form
local flagRenderer = class("flagRenderer", turbo.web.RequestHandler)

function flagRenderer:get(repo, origin, version)
    local pkg = { origin = origin, repo = repo, version = version }
    local exists = cntrl.isOrigin(conf.default.branch, repo, origin, version)
    local flagged = cntrl.isFlagged(origin, repo, version)
    if exists and not flagged then
        self:write(cntrl.flag(pkg))
    else
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
end

function flagRenderer:post(repo, origin, version)
    local m = {}
    local args = {
        from = self:get_argument("from", "", true),
        new_version = self:get_argument("new_version", "", true),
        message = self:get_argument("message", "", true),
        responce = self:get_argument("g-recaptcha-response", "", true),
    }
    local pkg = { origin=origin, repo=repo, version=version }
    m.form = {value=args}
    if cntrl.isFlagged(origin, repo, version) then
        error(turbo.web.HTTPError(404, "404 Page not found."))
    -- check if email is valid
    elseif not is_valid_email(args.from) then
        m.form.from = {class="input-error"}
        self:write(cntrl.flag(pkg, m))
    -- check if new version is provided
    elseif args.new_version == "" then
        m.form.version = {class="input-error"}
        self:write(cntrl.flag(pkg, m))
    -- check if message is provided
    elseif args.message == "" then
        m.form.message = {class="input-error"}
        self:write(cntrl.flag(pkg, m))
    -- check if recaptcha is correct
    elseif conf.rc.enabled and not cntrl.verifyRecaptcha(args.responce) then
        m.alert = {type="danger",msg="reCAPTCHA failed, please try again"}
        self:write(cntrl.flag(pkg, m))
    -- try to flag the package
    elseif not cntrl.flagOrigin(args, pkg) then
        m.alert = {type="danger",msg="Could not flag package, please try again"}
        self:write(cntrl.flag(pkg, m))
    -- successfully flagged, lets display the flagged origin package
    else
        local maintainer = cntrl.getMaintainer(conf.default.branch, origin)
        if maintainer and is_valid_email(maintainer.email) then
            pkg.memail = maintainer.email
            local r, e = cntrl.flagMail(args, pkg)
            if not r then turbo.log.warning(e) end
        end
        m.alert = {type="success",msg="Succesfully flagged package"}
        args = { origin = pkg.origin, repo = pkg.repo, page = 1 }
        self:write(cntrl.flagged(args, m))
    end
end

local flaggedRenderer = class("flaggedRenderer", turbo.web.RequestHandler)

function flaggedRenderer:get()
    local args = {
        origin = self:get_argument("origin", "", true),
        repo = self:get_argument("repo", "", true),
        maintainer = self:get_argument("maintainer", "", true),
        page = tonumber(self:get_argument("page", 1, true)) or 1,
    }
    self:write(cntrl.flagged(args))
end

local function cleanup(loop)
    turbo.log.notice("Stopping application.")
    cntrl:cleanup()
    loop:close()
end

turbo.web.Application({
    {"^/$", turbo.web.RedirectHandler, "/packages"},
    {"^/contents$", contentsRenderer},
    {"^/packages$", packagesRenderer},
    {"^/package/(.*)/(.*)/(.*)/(.*)$", packageRenderer},
    {"^/flag/(.*)/(.*)/(.*)$", flagRenderer},
    {"^/flagged$", flaggedRenderer},
    {"^/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
    {"^/robots.txt", turbo.web.StaticFileHandler, "assets/robots.txt"},
}):listen(tonumber(os.getenv("TURBO_PORT")) or conf.port)
local loop = turbo.ioloop.instance()
loop:add_signal_handler(2, cleanup, loop)
loop:add_signal_handler(15, cleanup, loop)
loop:start()
