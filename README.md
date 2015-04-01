# aports-turbo
Alpine Linux package database written in Lua.

This application makes use of the Turbo (Lua) framework. You can find more information about Turbo at: http://turbolua.org

On Alpine Linux it should be enough to install turbo by: 

apk add lua-turbo

and execute:

luajit aports.lua

A webserver should be listening on port number 8888.
