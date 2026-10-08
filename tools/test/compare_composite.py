#!/usr/bin/env python3
# Compare two t_composite.luau outputs: compare_composite.py a.txt b.txt
import sys
def load(p):
    rows = {}
    for l in open(p):
        if l.startswith("ROW"):
            _, y, h = l.split(); rows[int(y)] = bytes.fromhex(h)
    return rows
a, b = load(sys.argv[1]), load(sys.argv[2])
assert a and len(a) == len(b), "missing/uneven output"
diff = big = 0; worst = 0
for y in a:
    for x, (p, q) in enumerate(zip(a[y], b[y])):
        d = abs(p - q)
        if d: diff += 1
        if d > 2: big += 1
        worst = max(worst, d)
print("channels differing: %d, by more than 2: %d, max diff: %d" % (diff, big, worst))
sys.exit(1 if big else 0)
