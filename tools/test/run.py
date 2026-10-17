#!/usr/bin/env python3
"""Headless test harness: runs build/ImGui.luau + a main script in the Luau CLI against a mocked Roblox
(roblox_mock.luau). Rebuilds the bundle first.

  python3 tools/test/run.py                      # 400 frames of examples/example_roblox/main.client.luau, scripted random input
  python3 tools/test/run.py --open               # force every CollapsingHeader/TreeNode open (exercises whole demo)
  python3 tools/test/run.py --main my_test.luau  # different LocalScript
"""
import argparse, os, shutil, subprocess, sys, tempfile
TMP = tempfile.mkdtemp(prefix="imgui_test_")  # per process: parallel runs must not share files

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LUAU = shutil.which("luau") or (sorted(__import__("glob").glob("/nix/store/*-luau-*/bin/luau")) or ["luau"])[-1]
G = "game, workspace, Instance, Enum, Vector2, Vector3, UDim2, Color3, Content, UDim, CFrame, warn, require, script, os"

def build_run(args, flags):
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "bundle.py"), TMP] + (["--no-demo"] if os.environ.get("NO_DEMO") else []), check=True, stdout=subprocess.DEVNULL)
    if os.environ.get("MINIFY"):  # test the minified bundle instead (error line numbers won't map back to sources)
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "minify.py"), os.path.join(TMP, "ImGui.luau"), os.path.join(TMP, "ImGui.luau")], check=True, stdout=subprocess.DEVNULL)
    out = ["--" if args.roblox else "--!native", "--!optimize 2", flags, "local SOURCE_FNS = {}"]
    def add(key, path):
        s = "\n".join(l for l in open(path).read().split("\n") if not l.startswith("--!"))
        out.append("SOURCE_FNS[%r] = function(%s)\n%s\nend" % (key, G, s))
    add("ImGui.luau", os.path.join(TMP, "ImGui.luau"))
    add("main.client.luau", args.main)
    for m in args.module:  # [extensions] NAME=path -> ReplicatedStorage.NAME ModuleScript
        name, path = m.split("=", 1)
        add(name, path)
    out.append("EXTRA_MODULES = {%s}" % ",".join(repr(m.split("=", 1)[0]) for m in args.module))
    out.append(open(os.path.join(HERE, "roblox_mock.luau")).read())
    global OFFSET, LAST_LINE, STRIPPED
    bundle = open(os.path.join(TMP, "ImGui.luau")).read()
    LAST_LINE = bundle.count("\n")
    STRIPPED = sum(l.startswith("--!") for l in bundle.split("\n"))  # removed by add() (all at the top)
    OFFSET = 5  # lines before the ImGui function body in run.luau (flags/header lines + "function(...)" line)
    path = os.path.join(TMP, "run.luau")
    open(path, "w").write("\n".join(out))
    return path

def run(args, extra=""):
    flags = "ARG_FRAMES=%d; ARG_BIG=%s; ARG_OPEN=%s; ARG_QUIET=%s; %s" % (args.frames, str(args.big).lower(), ("{%s}" % ",".join("[%r]=true" % x for x in args.open_only.split(",")) if args.open_only else str(args.open).lower()), str(args.quiet).lower(), extra)
    try:
        p = subprocess.run([LUAU, "-O2"] + (["--profile=2000"] if args.profile else ["--codegen"]) + [build_run(args, flags)], capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired as e:
        return 124, "TIMEOUT (infinite loop?)\n" + remap((e.stdout or b"").decode(errors="replace"))
    return p.returncode, remap(p.stdout + p.stderr)

def remap(text):
    """run.luau:N -> <file>.lua:M"""
    import json, re
    lm = json.load(open(os.path.join(TMP, "ImGui.linemap.json")))
    def sub(m):
        n = int(m.group(1)) - OFFSET + STRIPPED  # line inside build/ImGui.luau
        best = None
        if n > LAST_LINE: return "<harness>:%d" % n
        for start, name in lm:
            if start <= n: best = (start, name)
        if not best: return m.group(0)
        return "%s:%d" % (best[1], n - best[0] + 1)
    return re.sub(r"\S*run\.luau:(\d+)", sub, text)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=400)
    ap.add_argument("--main", default=os.path.join(ROOT, "examples", "example_roblox", "main.client.luau"))
    ap.add_argument("--big", action="store_true", help="demo window forced to 900x1000")
    ap.add_argument("--roblox", action="store_true", help="like Studio: only @native functions get native code (default: whole bundle native)")
    ap.add_argument("--open-only", default="", help="comma list of CollapsingHeader/TreeNode labels to force open, e.g. Widgets,Basic")
    ap.add_argument("--profile", action="store_true", help="sampling profile (no codegen) -> profile.out; see tools/test/prof.py")
    ap.add_argument("--open", action="store_true", help="force all CollapsingHeader/TreeNode open")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--module", action="append", default=[], help="NAME=path: extra ModuleScript in ReplicatedStorage (extension repos)")
    ap.add_argument("--quiet", action="store_true", help="no random input (scripted tests drive io themselves)")
    args = ap.parse_args()

    code, out = run(args, os.environ.get("RUN_FLAGS", ""))
    print(out if os.environ.get("FULL_OUTPUT") else out[-4000:])
    sys.exit(code)

try:
    main()
finally:
    shutil.rmtree(TMP, ignore_errors=True)
