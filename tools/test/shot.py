#!/usr/bin/env python3
"""Headless screenshot: tools/test/shot.py out.png [--app]  (runs scripts/t_shot.luau, writes a PNG; stdlib only)"""
import os, subprocess, sys, struct, zlib
HERE = os.path.dirname(os.path.abspath(__file__))
env = dict(os.environ, FULL_OUTPUT="1", RUN_FLAGS="ARG_APP=true" if "--app" in sys.argv else "")
out = subprocess.run([sys.executable, os.path.join(HERE, "run.py"), "--quiet", "--roblox", "--frames", "30", "--timeout", "600",
                      "--main", os.path.join(HERE, "scripts", "t_shot.luau")], env=env, capture_output=True, text=True).stdout
rows = {int(l.split()[1]): bytes.fromhex(l.split()[2]) for l in out.splitlines() if l.startswith("ROW")}
assert rows, out[-2000:]
w, h = len(rows[0]) // 3, len(rows)
raw = b"".join(b"\0" + rows[y] for y in range(h))
chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
open(sys.argv[1], "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
print("wrote", sys.argv[1], w, h)
