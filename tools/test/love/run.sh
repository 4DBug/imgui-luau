#!/bin/sh
# LÖVE/LuaJIT checks: build the love bundle, compare draw checksums with the Luau ones, run both LÖVE examples headless.
set -e
cd "$(dirname "$0")/../../.."
python3 tools/bundle.py --target love >/dev/null
nix-shell -p luajit --run "luajit tools/test/love/t_drawhash.lua 150 Widgets,Basic && luajit tools/test/love/t_drawhash.lua 150 all && luajit tools/test/love/t_examples.lua"
echo "expected (Luau, tools/test/scripts/t_drawhash.luau): 1385106188 / 1292122782"
