#!/usr/bin/env python3
"""Static check: ImGui.X / ImGui:X / global ImFoo() calls in imgui/*.lua that nothing defines.
  python3 tools/test/undefined.py
"""
import os, re, collections
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "imgui")
files = {}
for dp, _, fn in os.walk(SRC):
    for f in fn:
        if f.endswith(".lua"):
            files[os.path.relpath(os.path.join(dp, f), SRC)] = open(os.path.join(dp, f)).read()

def strip(s):  # drop comments and strings (roughly) so we don't report text
    s = re.sub(r"--\[(=*)\[.*?\]\1\]", "", s, flags=re.S)
    s = re.sub(r"\[(=*)\[.*?\]\1\]", '""', s, flags=re.S)
    s = re.sub(r'"(\\.|[^"\\\n])*"', '""', s)
    s = re.sub(r"'(\\.|[^'\\\n])*'", "''", s)
    return re.sub(r"--[^\n]*", "", s)

defined_imgui, defined_global, used = set(), set(), collections.defaultdict(list)
for name, src in files.items():
    s = strip(src)
    defined_imgui.update(re.findall(r"function\s+ImGui[.:](\w+)", s))
    defined_imgui.update(re.findall(r"\bImGui\.(\w+)\s*=[^=]", s))
    defined_global.update(re.findall(r"^\s*function\s+([A-Za-z_]\w*)\s*\(", s, re.M))
    defined_global.update(re.findall(r"^\s*([A-Za-z_]\w*)\s*=[^=]", s, re.M))
    defined_global.update(re.findall(r"^\s*local\s+function\s+([A-Za-z_]\w*)", s, re.M))
    defined_global.update(re.findall(r"^\s*local\s+([A-Za-z_][\w, ]*)", s, re.M) and
                          [x.strip() for l in re.findall(r"^\s*local\s+([A-Za-z_][\w, ]*)", s, re.M) for x in l.split(",")])
    for i, line in enumerate(s.split("\n"), 1):
        for m in re.findall(r"\bImGui\.(\w+)\s*\(", line):
            used[("ImGui." + m, m, True)].append("%s:%d" % (name, i))
        for m in re.findall(r"(?<![.:\w])(Im[A-Z]\w*)\s*\(", line):
            used[(m, m, False)].append("%s:%d" % (name, i))

missing = [(k, v) for k, v in used.items() if (k[1] not in defined_imgui if k[2] else k[1] not in defined_global)]
for (full, _, _), locs in sorted(missing):
    print("%-45s %d uses, e.g. %s" % (full, len(locs), ", ".join(locs[:3])))
print("total undefined:", len(missing))
