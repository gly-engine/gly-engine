#!/bin/sh

set -e

if [ -n "$LUA_BIN" ] && "$LUA_BIN" -v >/dev/null 2>&1; then
    "$LUA_BIN" ./source/cli/main.lua "$@"
elif lua -v >/dev/null 2>&1; then
    lua ./source/cli/main.lua "$@"
elif lua5.4 -v >/dev/null 2>&1; then
    lua5.4 ./source/cli/main.lua "$@"
elif lua54 -v >/dev/null 2>&1; then
    lua54 ./source/cli/main.lua "$@"
elif lua5.3 -v >/dev/null 2>&1; then
    lua5.3 ./source/cli/main.lua "$@"
elif lua53 -v >/dev/null 2>&1; then
    lua53 ./source/cli/main.lua "$@"
elif lua5.2 -v >/dev/null 2>&1; then
    lua5.2 ./source/cli/main.lua "$@"
elif lua52 -v >/dev/null 2>&1; then
    lua52 ./source/cli/main.lua "$@"
elif lua5.1 -v >/dev/null 2>&1; then
    lua5.1 ./source/cli/main.lua "$@"
elif lua51 -v >/dev/null 2>&1; then
    lua51 ./source/cli/main.lua "$@"
elif luajit -v >/dev/null 2>&1; then
    luajit ./source/cli/main.lua "$@"
else
    echo -e "Lua not found!\nPlease install Lua or set the LUA_BIN environment variable."
    exit 1
fi
