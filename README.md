# aports-turbo
Alpine Linux package database written in Lua.

This application makes use of the Turbo (Lua) framework. You can find more information about Turbo at: http://turbolua.org

On Alpine Linux it should be enough to install turbo by: 

apk add lua-turbo lua-dbi-sqlite lua-lustache lua-socket

set config options in conf.lua

and execute:

turbovisor aports.lua --ignore ./db/persistent

A webserver should be listening on configured port.
