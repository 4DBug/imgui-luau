#!/usr/bin/env python3
# Summarise profile.out from `run.py --profile`: top functions by self and inclusive samples, mapped to source file lines
import collections, json, os, re, sys, glob
path = sys.argv[1] if len(sys.argv) > 1 else "profile.out"
tmp = max(glob.glob("/tmp/imgui_test_*/ImGui.linemap.json"), key=os.path.getmtime)
lm = json.load(open(tmp))
def loc(n):
    if not n.isdigit(): return "C"
    n = int(n) - 5 + 2; best = None
    for start, name in lm:
        if start <= n: best = (start, name)
    return "%s:%d" % (best[1], n - best[0] + 1) if best else "?"
self_, incl, total = collections.Counter(), collections.Counter(), 0
for line in open(path):
    cnt, stack = line.split(" ", 1); cnt = int(cnt); total += cnt
    frames = [f.rsplit(",", 2) for f in stack.strip().split(";")]
    keys = ["%s (%s)" % (f[1] or "?", loc(f[2])) for f in frames]
    self_[keys[0]] += cnt
    for k in set(keys): incl[k] += cnt
for title, c in (("SELF", self_), ("INCLUSIVE", incl)):
    print("== %s (%% of %d)" % (title, total))
    for k, v in c.most_common(int(os.environ.get("N", 30))): print("%5.1f%%  %s" % (100 * v / total, k))
