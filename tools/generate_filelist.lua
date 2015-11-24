#!/usr/bin/env luajit

local lfs = require("lfs")
local cjson = require("cjson")

local src = "/var/www/localhost/htdocs/alpine/edge"
local dst = "/var/tmp/filelist"
local filelist = "/var/www/localhost/filelist"
local repos = {"main","testing", "community"}
local archs = {"x86","x86_64","armhf"}
local dirfmt = "%s/%s/%s"
local logging = false

function build(repo, arch)
    local src = dirfmt:format(src, repo, arch)
    local dst = dirfmt:format(dst, repo, arch)
    local tarfmt = "tar ztf '%s' > %s"
    for apk in lfs.dir(src) do
        if apk:match(".apk$") then
            local lst = string.format("%s/%s.lst", dst, apk)
            if not lfs.attributes(lst) then
                local apk = string.format("%s/%s", src, apk)
                os.execute(tarfmt:format(apk, lst))
            end
        end
    end
end

function create_json(repo, arch)
    local dst = dirfmt:format(dst, repo, arch)
    local src = dirfmt:format(src, repo, arch)
    local result = {}
    for lst in lfs.dir(dst) do
        if lst:match("%.lst$") then
            local pkgname = lst:match("(.*)%-.*%-.*$")
            local r = {}
            local f = io.open(dst.."/"..lst)
            for line in f:lines() do
                if not (line:match("^%.") or line:match("/$")) then
                    local path, file
                    if line:match("/") then
                        path, file = line:match("(.*/)(.*)")
                        if path:sub(-1) == "/" then
                            path = (path:sub(1, -2))
                        end
                    else
                        path = ""
                        file = line
                    end
                    table.insert(r, {file, path})
                end
            end
            f:close()
            result[pkgname] = r
        end
    end
    local json = string.format("%s/%s-%s.json", filelist, repo, arch)
    os.execute("rm -f "..json..".gz")
    local g = io.open(json, "w")
    g:write(cjson.encode(result))
    g:close()
    os.execute("gzip "..json)
end

function clean(repo, arch)
    local dst = dirfmt:format(dst, repo, arch)
    local src = dirfmt:format(src, repo, arch)
    for lst in lfs.dir(dst) do
        local apk = lst:sub(1,-5)
        if not lfs.attributes(src.."/"..apk) then
            os.remove(dst.."/"..lst)
        end
    end
end

function index_changed(repo, arch)
    local json = string.format("%s/%s-%s.json.gz", filelist, repo, arch)
    local index = string.format("%s/%s/%s/APKINDEX.tar.gz", src, repo, arch)
    local index_attr = lfs.attributes(index)
    local json_attr = lfs.attributes(json)
    if (json_attr == nil) or (index_attr.modification > json_attr.modification) then
        return true
    end
end

function log(msg)
    if logging then 
        if logging == "syslog" then
            os.execute("logger "..msg)
        else
            print(msg)
        end
    end
end

for _,repo in ipairs(repos) do
    lfs.mkdir(dst.."/"..repo)
    for _,arch in ipairs(archs) do
        if index_changed(repo, arch) then
            lfs.mkdir(dirfmt:format(dst, repo, arch))
            log(string.format("Building %s/%s", repo, arch))
            build(repo, arch)
            log(string.format("Cleaning %s/%s", repo, arch))
            clean(repo, arch)
            log(string.format("Create json %s/%s", repo, arch))
            create_json(repo, arch)
        else
            log(string.format("No changes found for %s/%s", repo, arch))
        end
    end
end
