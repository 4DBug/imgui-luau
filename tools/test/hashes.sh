#!/usr/bin/env bash
# Draw-data checksums of the working tree vs a git rev (default HEAD), to prove a change renders identically.
#   tools/test/hashes.sh [rev]
# lib  = t_libhash (library only, no demo): must stay equal unless rendering is meant to change
# demo = t_drawhash with Widgets,Basic / whole demo open: changes with any demo edit
cd "$(dirname "$0")/../.."
export PATH="$PATH:/nix/store/2m2ja613nndihc8qm10f2rhq6znp1nh4-luau-0.734/bin:/nix/store/4qxq4arv32ly13kl3g0m5q80gm3a35xr-luajit-2.1.1741730670/bin"
REV=${1:-HEAD}
hashes() { # $1 = repo dir
    ( cd "$1"
      R="python3 tools/test/run.py --quiet --roblox --timeout 600"
      echo "lib        $(NO_DEMO=1 $R --main "$OLDPWD/tools/test/scripts/t_libhash.luau" --frames 120 | grep -o 'LIBHASH.*')" &
      echo "demo-basic $($R --main tools/test/scripts/t_drawhash.luau --frames 150 --open-only Widgets,Basic | grep -o 'DRAWHASH.*')" &
      echo "demo-all   $($R --main tools/test/scripts/t_drawhash.luau --frames 150 --open | grep -o 'DRAWHASH.*')" &
      echo "love-basic $(python3 tools/bundle.py --target love >/dev/null; luajit tools/test/love/t_drawhash.lua 60 Widgets,Basic | grep -o 'DRAWHASH.*')" &
      wait ) | tr "\t" " " | sort
}
W=$(mktemp -d /tmp/imgui_rev.XXXX)
git worktree add -q --detach "$W" "$REV"
hashes "$W" > "$W.old" & hashes . > "$W.new"; wait
git worktree remove --force "$W"
echo "check        $REV                         working tree"
paste "$W.old" "$W.new" | awk -F'\t' '{split($1,a," "); split($2,b," "); printf "%-12s %-30s %-30s %s\n", a[1], a[3], b[3], (a[3]==b[3]?"same":"CHANGED")}'
