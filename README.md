# aports-turbo

Alpine Linux package database written in Lua.

This application makes use of the [Turbo](http://turbolua.org) (Lua) framework.

On Alpine Linux it should be enough to install turbo and deps by: 

apk add luajit lua5.1 lua-turbo lua-sqlite lua-lustache lua-socket

Copy config.sample.lua to config.lua and edit it.
You can start the application by starting ./aports.lua or on Alpine Linux with turbo's init.d (see conf.d/turbo for settings)

#### Creating/updating the database

aports-turbo uses an sqlite database which is generated (check config to init tables) and updated by import.lua found in the tools directory. import.lua needs to be run from the root of aports-turbo project. You can for example run it from cron by creating a file like:

/etc/periodic/15min/alpine-turbo

```shell
#!/bin/sh

webdir="/var/www/aports-turbo"

cd $webdir && luajit tools/import.lua > /dev/null 2>&1
```
