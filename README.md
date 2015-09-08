# aports-turbo
Alpine Linux package database written in Lua.

This application makes use of the Turbo (Lua) framework. You can find more information about Turbo at: http://turbolua.org

On Alpine Linux it should be enough to install turbo and deps by: 

apk add luajit lua-turbo lua-sqlite lua-lustache lua-socket lua-cjson

copy conf.lua.default to conf.lua and provide defaults

execute: ./aports.lua

A webserver should be listening on configured port.
