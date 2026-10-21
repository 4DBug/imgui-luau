#!/usr/bin/env bash
# All local checks: CI's "Check" step (release.yml) + every scripted test + whole demo forced open + LÖVE.
# Usage: tools/test/check_all.sh            (prints PASS/FAIL per check, exit 1 if any failed)
#        HASHES=1 tools/test/check_all.sh   (also prints the draw-data checksums, see hashes.sh)
cd "$(dirname "$0")/../.."
export PATH="$PATH:/nix/store/2m2ja613nndihc8qm10f2rhq6znp1nh4-luau-0.734/bin:/nix/store/4qxq4arv32ly13kl3g0m5q80gm3a35xr-luajit-2.1.1741730670/bin"
command -v luau >/dev/null || { l=$(ls -d /nix/store/*-luau-*/bin 2>/dev/null | tail -1); [ -n "$l" ] && export PATH="$PATH:$l"; }
command -v luajit >/dev/null || { l=$(ls -d /nix/store/*-luajit-2*/bin 2>/dev/null | grep -v -- -env | tail -1); [ -n "$l" ] && export PATH="$PATH:$l"; }
T=$(mktemp -d /tmp/imgui_check.XXXX)
R="python3 tools/test/run.py --quiet --roblox --timeout 600"

# name | expected output | command
CHECKS=(
"readme|README OK|$R --main tools/test/scripts/t_readme.luau --frames 30"
"readme-min|README OK|MINIFY=1 $R --main tools/test/scripts/t_readme.luau --frames 30"
"cached|CACHED OK|$R --main tools/test/scripts/t_cached_window.luau --frames 130"
"fixes|FIXES OK|$R --main tools/test/scripts/t_fixes.luau --frames 55"
"debugtools|DEBUGTOOLS OK|$R --main tools/test/scripts/t_debugtools.luau --frames 65"
"helpers|HELPERS OK|$R --main tools/test/scripts/t_helpers.luau --frames 45"
"multiselect|MULTISELECT OK|$R --main tools/test/scripts/t_multiselect.luau --frames 380"
"nodemo|NODEMO OK|NO_DEMO=1 $R --main tools/test/scripts/t_nodemo.luau --frames 25"
"widgets|OK|$R --main tools/test/scripts/t_widgets.luau --frames 80"
"tables|OK|$R --main tools/test/scripts/t_tables.luau --frames 150"
"tabs|scrollbtn.true|$R --main tools/test/scripts/t_tabs.luau --frames 60"
"modal|round trip ok|$R --main tools/test/scripts/t_modal.luau --frames 40"
"dock|DOCK OK|$R --main tools/test/scripts/t_dock.luau --frames 60"
"dock_close|DOCK CLOSE OK|$R --main tools/test/scripts/t_dock_close.luau --frames 60"
"dock_drag|OK|$R --main tools/test/scripts/t_dock_drag.luau --frames 80"
"dock_ini|ROUNDTRIP OK|$R --main tools/test/scripts/t_dock_ini.luau --frames 60"
"dock_move|OK|$R --main tools/test/scripts/t_dock_move.luau --frames 80"
"passthru|PASSTHRU OK|$R --main tools/test/scripts/t_passthru.luau --frames 40"
"fonts|FONTS OK|$R --main tools/test/scripts/t_fonts.luau --frames 8"
"textproxy|PROXY OK|$R --main tools/test/scripts/t_textproxy.luau --frames 30"
"textproxy_custom|CUSTOM PROXY OK|$R --main tools/test/scripts/t_textproxy_custom.luau --frames 15"
"style_editor|SE OK|$R --main tools/test/scripts/t_style_editor.luau --frames 20"
"style_leak|STYLE OK|$R --main tools/test/scripts/t_style_leak.luau --frames 60 --open"
"apps|APPS OK|$R --main tools/test/scripts/t_apps.luau --frames 120 --open"
"libhash|LIBHASH|NO_DEMO=1 $R --main tools/test/scripts/t_libhash.luau --frames 120"
"demo_open|DRAWHASH|$R --main tools/test/scripts/t_drawhash.luau --frames 150 --open"
"demo_random|^|python3 tools/test/run.py --roblox --timeout 600 --frames 400 --open"
"pixels|PIXELS SAME|a=\$($R --main tools/test/scripts/t_pixels.luau --frames 600 | grep -P '^PIX\t'); b=\$(RUN_FLAGS=ARG_FORCE=true $R --main tools/test/scripts/t_pixels.luau --frames 600 | grep -P '^PIX\t'); [ -n \"\$a\" ] && [ \"\$a\" = \"\$b\" ] && echo PIXELS SAME"
"move_pixels|MOVEPIX SAME|a=\$($R --main tools/test/scripts/t_move_pixels.luau --frames 245 | grep -P '^PIX\t'); b=\$(RUN_FLAGS=ARG_FORCE=true $R --main tools/test/scripts/t_move_pixels.luau --frames 245 | grep -P '^PIX\t'); [ -n \"\$a\" ] && [ \"\$a\" = \"\$b\" ] && echo MOVEPIX SAME"
"rect_flip|RECTFLIP OK|$R --main tools/test/scripts/t_rect_flip.luau --frames 30"
"tile_bound|TILEBOUND OK|$R --main tools/test/scripts/t_tile_bound.luau --frames 200"
"parallel|PARALLEL OK|$R --main tools/test/scripts/t_parallel.luau --frames 620"
"pool_ctx|POOLCTX OK|$R --main tools/test/scripts/t_pool_ctx.luau --frames 60"
"assets_scroll|ASSETS OK|$R --main tools/test/scripts/t_assets_scroll.luau --frames 1010"
"shot|wrote|python3 tools/test/shot.py /tmp/imgui_shot.png --app"
"registers|REGS OK|mkdir -p $T/regs && python3 tools/bundle.py $T/regs >/dev/null && h=\"\$(printf 'local _h%d = {} ' \$(seq 20))\" && grep -q \"^__FILES\\['imgui_impl_roblox.lua'\\] = function()\$\" $T/regs/ImGui.luau && for f in $T/regs/*.luau; do { echo \"\$h\"; sed \"/^__FILES\\['imgui_impl_roblox.lua'\\] = function()\$/a \$h\" \$f; } > \$f.h && luau-compile -O0 --null \$f.h || exit 1; done && ! grep -q require $T/regs/ImGuiWorker.client.luau && echo REGS OK"
"love|DRAWHASH|python3 tools/bundle.py --target love >/dev/null && luajit tools/test/love/t_drawhash.lua 60 Widgets,Basic && luajit tools/test/love/t_examples.lua"
)

run() { # $1=name $2=expect $3=cmd
    bash -c "$3" > "$T/$1.txt" 2>&1; code=$?
    if [ $code -eq 0 ] && grep -q "$2" "$T/$1.txt" && ! grep -qiE "error|traceback|stack begin|FAIL" "$T/$1.txt"; then echo "PASS $1"
    else echo "FAIL $1 (exit $code, log $T/$1.txt)"; tail -5 "$T/$1.txt" | sed 's/^/    /'; fi
}
for c in "${CHECKS[@]}"; do IFS='|' read -r n e cmd <<< "$c"; run "$n" "$e" "$cmd" & done > "$T/summary.txt"
wait
sort "$T/summary.txt"
[ -n "$HASHES" ] && tools/test/hashes.sh
! grep -q "^FAIL" "$T/summary.txt"
