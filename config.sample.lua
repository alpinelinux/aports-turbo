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
---- settings for alpine git repo
----
config.git = {}
----
-- url to alpine git browser
----
config.git.commit = "http://git.alpinelinux.org/cgit/aports/commit/?id=%s"
----
-- url to the git repo directory
----
config.git.pkgpath = "http://git.alpinelinux.org/cgit/aports/tree/%s/%s?h=%s"
----
-- url to the build log
----
config.buildlog = "http://build.alpinelinux.org/buildlogs/build-%s-%s/%s/%s/%s-%s.log"
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
----
---- settings for anitya (https://release-monitoring.org)
----
config.anitya = {}
-- name of the distribution on anitya
config.anitya.distro = "Alpine"
-- base uri of the anitya restful api
config.anitya.api_uri = "https://release-monitoring.org/api"
-- number of http requests to send concurrently
config.anitya.api_concurrency = 20
-- uri of the anitya fedmsg/zeromq interface
config.anitya.fedmsg_uri = "tcp://release-monitoring.org:9940"
-- text of the message to be sent to maintainer of an outdated package
config.anitya.flag_message = [[
This package has been flagged automatically on the basis of notification from
Anitya <https://release-monitoring.org/>.

Please note that integration with Anitya is in experimental phase.
If the provided information is incorrect, please let us know on IRC
or alpine-infra@alpinelinux.org. Thanks!]]

return config
