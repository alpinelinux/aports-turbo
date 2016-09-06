#!/usr/bin/env luajit

TURBO_SSL   = true
turbo       = require("turbo")

conf        = require("config")
cntrl       = require("controller")
model       = require("model")
db          = require("db")


-- packages renderer to display a list of packages
local packagesRenderer = class("packagesRenderer", turbo.web.RequestHandler)

function packagesRenderer:prepare()
    db:open()
end

function packagesRenderer:on_finish()
    db:close()
end

function packagesRenderer:get()
    local args = {
        name = self:get_argument("name","", true),
        branch = self:get_argument("branch", "", true),
        arch = self:get_argument("arch", "", true),
        repo = self:get_argument("repo", "", true),
        maintainer = self:get_argument("maintainer", "", true),
        page = tonumber(self:get_argument("page", 1, true)) or 1,
    }
    self:write(cntrl:packages(args))
end

-- package renderer, to display a single package
local packageRenderer = class("packageRenderer", turbo.web.RequestHandler)

function packageRenderer:prepare()
    db:open()
end

function packageRenderer:on_finish()
    db:close()
end

function packageRenderer:get(branch, repo, arch, name)
    local ops = {branch=branch,repo=repo,arch=arch, name=name}
    local pkg = cntrl:getPackage(ops)
    if next(pkg) then
        self:write(cntrl:package(pkg))
    else
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
end

local contentsRenderer = class("contentsRenderer", turbo.web.RequestHandler)

function contentsRenderer:prepare()
    db:open()
end

function contentsRenderer:on_finish()
    db:close()
end

function contentsRenderer:get()
    local args = {
        file = self:get_argument("file", "", true),
        path = self:get_argument("path", "", true),
        name = self:get_argument("name", "", true),
        branch = self:get_argument("branch", "", true),
        repo = self:get_argument("repo", "", true),
        arch = self:get_argument("arch", "", true),
        page = tonumber(self:get_argument("page", 1, true)) or 1,
    }
    self:write(cntrl:contents(args))
end

-- flagged renderer, to display the flag form
local flagRenderer = class("flagRenderer", turbo.web.RequestHandler)

function flagRenderer:prepare()
    db:open()
end

function flagRenderer:on_finish()
    db:close()
end

function flagRenderer:get(branch, repo, origin, version)
    local ops = {branch=branch, repo=repo, origin=origin, version=version}
    local pkg = cntrl:getNotFlagged(ops)
    if pkg then
        self:write(cntrl:flag(pkg))
    else
        error(turbo.web.HTTPError(404, "404 Page not found."))
    end
end

function flagRenderer:post(branch, repo, origin, version)
    local m = {}
    local args = {
        from = self:get_argument("from", "", true),
        new_version = self:get_argument("new_version", "", true),
        message = self:get_argument("message", "", true),
        responce = self:get_argument("g-recaptcha-response", "", true),
    }
    local ops = { branch=branch, repo=repo, name=origin, version=version }
    m.form = {value=args}
    local pkg = cntrl:getNotFlagged(ops)
    -- check if pkg exists and is not flagged
    if not pkg then
        error(turbo.web.HTTPError(404, "404 Page not found."))
    -- check if email is valid
    elseif not cntrl:validateEmail(args.from) then
        m.form.status = {from="has-error"}
        m.alert = {type="danger",msg="Please provide a valid email address"}
        self:write(cntrl:flag(pkg, m))
    -- check if new version is provided
    elseif args.new_version == "" then
        m.form.status = {new_version="has-error"}
        m.alert = {type="danger",msg="Please provide a new upstream version number"}
        self:write(cntrl:flag(pkg, m))
    -- check if message is provided
    elseif args.message == "" then
        m.form.status = {message="has-error"}
        m.alert = {type="danger",msg="Please provide a message"}
        self:write(cntrl:flag(pkg, m))
    -- check if recaptcha is correct
    elseif conf.rc.sitekey and not cntrl:verifyRecaptcha(args.responce) then
        m.alert = {type="danger",msg="reCAPTCHA failed, please try again"}
        self:write(cntrl:flag(pkg, m))
    -- try to flag the package
    elseif not db:flagOrigin(args, pkg) then
        m.alert = {type="danger",msg="Could not flag package, please try again"}
        self:write(cntrl:flag(pkg, m))
    -- successfully flagged, lets display the flagged origin package
    else
        if cntrl:validateEmail(pkg.memail) then
            cntrl:flagMail(args, pkg)
        end
        cntrl:clearCache()
        m.alert = {type="success",msg="Succesfully flagged package"}
        self:write(cntrl:package(pkg, m))
    end
end

local flaggedRenderer = class("flaggedRenderer", turbo.web.RequestHandler)

function flaggedRenderer:prepare()
    db:open()
end

function flaggedRenderer:on_finish()
    db:close()
end

function flaggedRenderer:get()
    local args = {
        origin = self:get_argument("origin","", true),
        branch = self:get_argument("branch", "", true),
        repo = self:get_argument("repo", "", true),
        maintainer = self:get_argument("maintainer", "", true),
        page = tonumber(self:get_argument("page", 1, true)) or 1,
    }
    self:write(cntrl:flagged(args))
end

turbo.web.Application({
    {"^/$", turbo.web.RedirectHandler, "/packages"},
    {"^/contents$", contentsRenderer},
    {"^/packages$", packagesRenderer},
    {"^/package/(.*)/(.*)/(.*)/(.*)$", packageRenderer},
    {"^/flag/(.*)/(.*)/(.*)/(.*)$", flagRenderer},
    {"^/flagged$", flaggedRenderer},
    {"^/assets/(.*)$", turbo.web.StaticFileHandler, "assets/"},
    {"^/robots.txt", turbo.web.StaticFileHandler, "assets/robots.txt"},
}):listen(conf.port)
cntrl:clearCache()
local loop = turbo.ioloop.instance()
loop:start()
