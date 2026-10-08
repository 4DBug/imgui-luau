#!/usr/bin/env python3
"""Headless test harness: runs build/ImGui.luau + a main script in the Luau CLI against a mocked Roblox
(roblox_mock.luau). Rebuilds the bundle first.

  python3 tools/test/run.py                      # 400 frames of main.client.luau, scripted random input
  python3 tools/test/run.py --open               # force every CollapsingHeader/TreeNode open (exercises whole demo)
  python3 tools/test/run.py --big --open --bench # timing, best of 5
  python3 tools/test/run.py --check              # incremental vs forced redraw must be pixel identical
  python3 tools/test/run.py --png out.png        # screenshot of the last frame
  python3 tools/test/run.py --main my_test.luau  # different LocalScript
"""
import argparse, os, shutil, subprocess, sys, zlib, struct, tempfile
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
    flags = "ARG_FRAMES=%d; ARG_BIG=%s; ARG_OPEN=%s; %s" % (args.frames, str(args.big).lower(), str(args.open).lower(), extra)
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

def images(out):
    return [l.split() for l in out.split("\n") if l.startswith("IMG ")]

def write_png(img, path, crop=None):
    _, fr, w, h, hx = img; w, h = int(w), int(h); px = bytes.fromhex(hx)
    W, H = crop or (w, h)
    raw = bytearray()
    for y in range(H):
        raw.append(0)
        for x in range(W):
            o = (y * w + x) * 4; r, g, b, a = px[o:o + 4]; k = a / 255
            raw += bytes([int(r * k + 90 * (1 - k)), int(g * k + 90 * (1 - k)), int(b * k + 90 * (1 - k))])
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(bytes(raw))) + chunk(b'IEND', b''))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=400)
    ap.add_argument("--main", default=os.path.join(ROOT, "main.client.luau"))
    ap.add_argument("--big", action="store_true", help="demo window forced to 900x1000")
    ap.add_argument("--open", action="store_true", help="force all CollapsingHeader/TreeNode open")
    ap.add_argument("--bench", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--png")
    ap.add_argument("--crop", default="1100x1080")
    ap.add_argument("--timeout", type=int, default=120)
    args = ap.parse_args()

    if args.bench:
        for mode in ["", "ARG_FORCE=true"]:
            best = None
            for _ in range(5):
                code, out = run(args, mode)
                if code: print(out[-3000:]); sys.exit(1)
                line = [l for l in out.split("\n") if l.startswith("avg frame")][-1]
                if best is None or float(line.split()[3]) < float(best.split()[3]): best = line
            print("%-12s %s" % (mode or "incremental", best))
        return
    if args.check:
        code, a = run(args, "ARG_DUMP=true")
        code2, b = run(args, "ARG_DUMP=true; ARG_FORCE=true")
        if code or code2: print((a if code else b)[-3000:]); sys.exit(1)
        ok = [x[4] for x in images(a)] == [x[4] for x in images(b)]
        print("PIXELS-IDENTICAL" if ok else "PIXELS-DIFFER"); sys.exit(0 if ok else 1)

    code, out = run(args, "ARG_DUMP=true" if args.png else "")
    print("\n".join(l if not l.startswith("IMG ") else l[:40] + "..." for l in out.split("\n"))[-4000:])
    if args.png and images(out):
        write_png(images(out)[-1], args.png, tuple(map(int, args.crop.split("x"))))
        print("wrote", args.png)
    sys.exit(code)

try:
    main()
finally:
    shutil.rmtree(TMP, ignore_errors=True)
