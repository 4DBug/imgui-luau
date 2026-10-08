#!/usr/bin/env python3
"""Lists upstream ImGui:: functions (tools/test/upstream/*.cpp, docking branch) that the Lua port doesn't define.
  python3 tools/test/missing.py              # summary per upstream file
  python3 tools/test/missing.py tables       # names missing from imgui_tables.cpp
"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
port = set()
for f in os.listdir(os.path.join(ROOT, "imgui")):
    if f.endswith(".lua"):
        port.update(re.findall(r"function ImGui[.:](\w+)", open(os.path.join(ROOT, "imgui", f)).read()))
filt = sys.argv[1] if len(sys.argv) > 1 else None
for f in sorted(os.listdir(os.path.join(HERE, "upstream"))):
    if not f.endswith(".cpp") or f == "imgui_demo.cpp": continue
    if filt and filt not in f: continue
    src = open(os.path.join(HERE, "upstream", f)).read()
    names = sorted(set(re.findall(r"^[\w:<>*& ]+?\bImGui::(\w+)\(", src, re.M)))
    miss = [n for n in names if n not in port]
    print("%-20s %4d/%4d ported, missing %d" % (f, len(names) - len(miss), len(names), len(miss)))
    if filt: print("  " + "\n  ".join(miss))
