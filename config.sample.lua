local config = {}
----
-- the application uri
----
config.uri = "http://pkgs.alpinelinux.org"
----
-- Turbo listening port
----
config.port = 8080
----
-- set the branches,repos,archs you want to include
----
config.branches = {"latest-stable", "edge"}
config.repos = {"main", "community", "testing"}
config.archs  = {"x86", "x86_64", "armhf"}
----
-- location of the mirror on disk
----
config.mirror = "/media/mirror/alpine"
----
-- database settings
----
config.db = {}
-- initialize database (create tables)
config.db.init = false
-- path to the sqlite db
config.db.path = "db/aports.db"
-- multi value db fields
config.db.fields = {"provides", "depends", "install_if"}
----
-- debug logging. true to enable to stdout, syslog to syslog
----
config.logging = true
----
-- google recaptcha settings
----
config.rc = {}
-- set sitekey to false to disable recaptcha
-- config.rc.sitekey = ""
config.rc.secret  = ""
----
-- mailer settings
----
config.mail = {}
config.mail.from = "Alpine Package DB <pkgs@alpinelinux.org>"
config.mail.server = "mail.alpinelinux.org"
config.mail.domain = "pkgs.alpinelinux.org"
----
-- settings for pagers
----
config.pager = {}
-- how many entries in page
config.pager.limit = 50
-- the left and right offset of the pager
config.pager.offset = 3
----
-- url to alpine git browser
----
config.giturl = "http://git.alpinelinux.org/cgit/aports/commit/?id=%s"
----
-- directory where views are stored
----
config.tpl = "views"
----
-- reverse proxy cache clear
----
config.cache = {}
-- enable or disable cache clear
config.cache.clear = true
-- path to the cache
-- if the path does not contain the name "cache" it will not work
config.cache.path = "/var/lib/nginx/cache"
-- the max depth to traverse (can be set by nginx cache settings)
config.cache.depth = 3

return config
