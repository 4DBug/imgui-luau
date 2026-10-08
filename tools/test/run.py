#!/usr/bin/env python3
"""Headless test harness: runs build/ImGui.luau + a main script in the Luau CLI against a mocked Roblox
(roblox_mock.luau). Rebuilds the bundle first.

  python3 tools/test/run.py                      # 400 frames of main.client.luau, scripted random input
  python3 tools/test/run.py --open               # force every CollapsingHeader/TreeNode open (exercises whole demo)
  python3 tools/test/run.py --main my_test.luau  # different LocalScript
"""
import argparse, os, shutil, subprocess, sys, tempfile
TMP = tempfile.mkdtemp(prefix="imgui_test_")  # per process: parallel runs must not share files

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
LUAU = shutil.which("luau") or "/nix/store/2m2ja613nndihc8qm10f2rhq6znp1nh4-luau-0.734/bin/luau"
G = "game, workspace, Instance, Enum, Vector2, Vector3, UDim2, Color3, Content, warn, require, script, os"

def build_run(args, flags):
    subprocess.run([sys.executable, os.path.join(ROOT, "tools", "bundle.py"), TMP], check=True, stdout=subprocess.DEVNULL)
    out = ["--!native", "--!optimize 2", flags, "local SOURCE_FNS = {}"]
    def add(key, path):
        s = "\n".join(l for l in open(path).read().split("\n") if not l.startswith("--!"))
        out.append("SOURCE_FNS[%r] = function(%s)\n%s\nend" % (key, G, s))
    add("ImGui.luau", os.path.join(TMP, "ImGui.luau"))
    add("main.client.luau", args.main)
    out.append(open(os.path.join(HERE, "roblox_mock.luau")).read())
    global OFFSET, LAST_LINE
    LAST_LINE = open(os.path.join(TMP, "ImGui.luau")).read().count("\n")
    OFFSET = 5  # lines before the ImGui function body in run.luau (flags/header lines + "function(...)" line)
    path = os.path.join(TMP, "run.luau")
    open(path, "w").write("\n".join(out))
    return path

def run(args, extra=""):
    flags = "ARG_FRAMES=%d; ARG_BIG=%s; ARG_OPEN=%s; ARG_QUIET=%s; %s" % (args.frames, str(args.big).lower(), str(args.open).lower(), str(args.quiet).lower(), extra)
    try:
        p = subprocess.run([LUAU, "-O2", "--codegen", build_run(args, flags)], capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired as e:
        return 124, "TIMEOUT (infinite loop?)\n" + remap((e.stdout or b"").decode(errors="replace"))
    return p.returncode, remap(p.stdout + p.stderr)

def remap(text):
    """run.luau:N -> imgui/<file>.lua:M"""
    import json, re
    lm = json.load(open(os.path.join(TMP, "ImGui.linemap.json")))
    def sub(m):
        n = int(m.group(1)) - OFFSET  # line inside build/ImGui.luau (minus its 2 stripped --! lines)
        n += 2
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
    ap.add_argument("--main", default=os.path.join(ROOT, "main.client.luau"))
    ap.add_argument("--big", action="store_true", help="demo window forced to 900x1000")
    ap.add_argument("--open", action="store_true", help="force all CollapsingHeader/TreeNode open")
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--quiet", action="store_true", help="no random input (scripted tests drive io themselves)")
    args = ap.parse_args()

    code, out = run(args, "")
    print(out[-4000:])
    sys.exit(code)

try:
    main()
finally:
    shutil.rmtree(TMP, ignore_errors=True)
