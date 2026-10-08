#!/usr/bin/env python3
# Renders README images into docs/images/: python3 tools/screenshots/make.py [scene ...]
# Stills -> PNG (zlib, stdlib only); the "plot" scene -> GIF via ffmpeg (palette).
import os, struct, subprocess, sys, tempfile, zlib
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "docs", "images")
STILLS = ["debug", "tool", "hello", "demo", "tables", "style", "metrics", "docking", "drawlist"]

def png(path, w, h, rows):
    raw = b"".join(b"\x00" + r for r in rows)
    def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

def run(scene):
    src = open(os.path.join(ROOT, "tools", "screenshots", "capture.luau")).read()
    tmp = os.path.join(tempfile.mkdtemp(), "scene.luau")
    open(tmp, "w").write('SCENE = "%s"\n' % scene + src)
    frames = 152 if scene == "plot" else 42
    p = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "test", "run.py"), "--main", tmp, "--frames", str(frames),
                        "--quiet", "--roblox", "--timeout", "1200"], capture_output=True, text=True, env=dict(os.environ, FULL_OUTPUT="1"))
    shots, size = {}, None
    for l in p.stdout.splitlines():
        if l.startswith("SIZE"): size = tuple(map(int, l.split()[1:]))
        elif l.startswith("PX"):
            _, f, y, hx = l.split(); shots.setdefault(int(f), {})[int(y)] = bytes.fromhex(hx)
    if not shots: sys.exit("scene %s failed:\n%s" % (scene, p.stdout[-3000:]))
    w, h = size
    return w, h, [[rows[y] for y in range(h)] for _, rows in sorted(shots.items())]

os.makedirs(OUT, exist_ok=True)
for scene in sys.argv[1:] or STILLS + ["plot"]:
    w, h, frames = run(scene)
    if scene == "plot":
        d = tempfile.mkdtemp()
        for i, rows in enumerate(frames): png(os.path.join(d, "f%04d.png" % i), w, h, rows)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "30", "-i", os.path.join(d, "f%04d.png"), "-vf",
                        "split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=none", "-loop", "0",
                        os.path.join(OUT, "plot.gif")], check=True)
    else:
        png(os.path.join(OUT, scene + ".png"), w, h, frames[-1])
    print("wrote", scene)
