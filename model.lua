local model     = class('model')

-- keys used in alpine linux repository index
function model:indexFormat(k)
    local f = {
        P = "name",
        V = "version",
        T = "description",
        U = "url",
        L = "license",
        A = "arch",
        D = "depends",
        C = "checksum",
        S = "size",
        I = "installed_size",
        p = "provides",
        i = "install_if",
        o = "origin",
        m = "maintainer",
        t = "build_time",
        c = "commit",
    }
    return k and f[k] or f
end

-- package format as stored in database
function model:packageFormat(k)
    local f = self:indexFormat()
    f.r = "repo"
    f.b = "branch"
    return k and f[k] or f
end

-- what happends here with version?
function model:packages(pkgs)
    local r = {}
    for k,v in pairs(pkgs) do
        r[k] = {}
        r[k].name = {
            path=string.format("/package/%s/%s/%s/%s", v.branch, v.repo, v.arch, v.name),
            text=v.name,
            title=v.description
        }
        r[k].version = {
            path=string.format("/flag/%s/%s/%s/%s", v.branch, v.repo, v.origin, v.version),
            text=v.version,
            title="Flag this package out of date"
        }
        r[k].url = {
            path=v.url,
            text="URL",
            title=v.url
        }
        r[k].license = v.license
        r[k].branch = v.branch
        r[k].arch = v.arch
        r[k].repo = v.repo
        r[k].maintainer = v.mname or "None"
        r[k].build_time = v.build_time
        if (v.fid) then r[k].flagged = {date=v.flagged} end
    end
    return r
end

function model:packagesForm(args, distinct)
    local m = {}
    m.name = args.name
    m.branch = self:FormSelect(distinct.branch, args.branch)
    m.repo = self:FormSelect(distinct.repo, args.repo)
    m.arch = self:FormSelect(distinct.arch, args.arch)
    m.maintainer = self:FormSelect(distinct.maintainer, args.maintainer)
    return m
end

function model:FormSelect(options, selected)
    local r = {}
    table.insert(options, 1, "")
    for k,v in pairs(options) do
        r[k] = {text=v}
        if (v==selected) then r[k].selected = "selected" end
    end
    return r
end

function model:package(pkg)
    local r = {}
    -- populate default values or None if not set.
    for _,v in pairs(self:packageFormat()) do
        r[v] = cntrl:isSet(pkg[v]) or "None"
    end
    r.nav = {package="active"}
    r.version = {text=pkg.version}
    if pkg.fid then 
        r.version.class = "text-danger"
        r.version.title = string.format("Flagged: %s", pkg.flagged)
        r.version.path = "#"
    else
        r.version.class = "text-success"
        r.version.title = string.format("Flag this package out of date")
        r.version.path = string.format("/flag/%s/%s/%s/%s",pkg.branch, pkg.repo, pkg.origin, pkg.version)
    end
    r.maintainer = pkg.mname or "None"
    r.origin = { 
        path=string.format("/package/%s/%s/%s/%s", pkg.branch, pkg.repo, pkg.arch, pkg.origin), 
        text=pkg.origin
    }
    r.commit = { 
        path=string.format(conf.giturl, pkg.commit), 
        text=pkg.commit
    }
    r.contents = { 
        path=string.format("/contents?branch=%s&name=%s&arch=%s&repo=%s", pkg.branch, pkg.name, pkg.arch, pkg.repo),
        text="Contents of package"
    }
    return r
end

function model:flagged(pkgs)
    local r = {}
    for k,v in pairs(pkgs) do
        r[k] = {}
        r[k].name = {
            path=string.format("/package/%s/%s/%s/%s", v.branch, v.repo, v.arch, v.name),
            text=v.name,
            title=v.description
        }
        r[k].version = v.version
        r[k].new_version = v.new_version
        r[k].branch = v.branch
        r[k].arch = v.arch
        r[k].repo = v.repo
        r[k].maintainer = v.mname or "None"
        r[k].created = v.created
        r[k].message = v.message
    end
    return r
end

function model:flaggedForm(args, distinct)
    local m = {}
    m.name = args.name
    m.branch = model:FormSelect(distinct.branch, args.branch)
    m.repo = model:FormSelect(distinct.repo, args.repo)
    m.arch = model:FormSelect(distinct.arch, args.arch)
    m.maintainer = model:FormSelect(distinct.maintainer, args.maintainer)
    return m
end

function model:packageRelations(pkgs)
    local r = {}
    for k,v in pairs(pkgs) do
        local path = string.format("/package/%s/%s/%s/%s", v.branch, v.repo, v.arch, v.name)
        table.insert(r, {path=path, text=v.name})
    end
    return r
end

function model:pagerModel(args, pager)
    local result = {}
    if pager.last > 1 then
        table.insert(pager, 1, "&laquo;")
        table.insert(pager, "&raquo;")
        for k,p in ipairs(pager) do
            local r = {}
            for g,v in pairs(args) do
                if (g=="page") then
                    if p == "&laquo;" then
                        v=1
                    elseif p == "&raquo;" then
                        v=pager.last
                    else
                        v=p
                    end
                end
                if v ~= "" then
                    r[#r+1]=string.format("%s=%s", cntrl:urlEncode(g), cntrl:urlEncode(v))
                end
            end
            path = table.concat(r, '&amp;')
            class = (args.page == p) and "active" or ""
            table.insert(result, {args=path, class=class, page=p})
        end
    end
    return result
end

function model:contents(cnt)
    local r = {}
    for k,v in pairs(cnt) do
        r[k] = {}
        r[k].branch = v.branch
        r[k].repo = v.repo
        r[k].arch = v.arch
        r[k].file = string.format("%s/%s", v.path, v.file)
        r[k].pkgname = {}
        r[k].pkgname.path = string.format("/package/%s/%s/%s/%s", v.branch, v.repo, v.arch, v.name)
        r[k].pkgname.text = v.name
    end
    return r
end

function model:contentsForm(args, distinct)
    local m = {}
    m.file = args.file
    m.path = args.path
    m.name = args.name
    m.branch = self:FormSelect(distinct.branch, args.branch)
    m.repo = self:FormSelect(distinct.repo, args.repo)
    m.arch = self:FormSelect(distinct.arch, args.arch)
    return m
end

function model:flag(pkg, m)
    m = m or {}
    m.form = m.form or {}
    m.nav = {flagged="active"}
    m.repo = pkg.repo
    m.origin = pkg.origin
    m.version = pkg.version
    m.maintainer = pkg.mname or "None"
    m.sitekey = conf.rc.sitekey
    return m
end

function model:flagMail(pkg, args)
    return {
        maintainer = pkg.mname,
        origin = pkg.origin,
        from = args.from,
        message = args.message
    }
end

return model()