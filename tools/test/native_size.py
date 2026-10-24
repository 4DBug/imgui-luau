#!/usr/bin/env python3
"""Native code size of the Roblox bundle (and the worker), per ModuleScript, per source file and per function.

  python3 tools/test/native_size.py              # bundles to a temp dir, measures ImGui.luau + ImGuiWorker.client.luau
  python3 tools/test/native_size.py --top 40     # also the 40 largest @native functions (with source file:line)
  python3 tools/test/native_size.py a.luau ...   # measure given files (e.g. an extension: ImPlot.lua)

Why: Roblox compiles each script's @native functions together into ONE allocation that must fit in one 4 MB block
of executable memory (Luau CodeGen's CodeAllocator, LuauCodeGenBlockSize). A module whose native code is bigger gets
NO native code at all, silently: every @native function of it runs interpreted (Studio: render 4-9x slower). Measured
in Studio (probe bundles, Oct 2026): native up to 4,083,418 bytes, interpreted from 4,103,258 bytes (sizes as reported
by luau-compile 0.738 --codegennull -O2 for x64). The Luau CLI fails a little later (~4.18 MB), and `run.py` puts the
bundle, the main script and every --module into one chunk, so headless runs with ImPlot hit it ~0.5 MB earlier.
Prints NATIVE OK when every module is under BUDGET (margin for compiler version drift), NATIVE OVER otherwise."""
import argparse, glob, json, os, shutil, subprocess, sys, tempfile, collections

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
STUDIO_LIMIT = 4083418  # largest module measured native in Studio (next probe, 4,103,258, ran interpreted)
BUDGET = 3900000        # NATIVE OVER above this (~180 KB margin below the Studio limit)
LC = shutil.which("luau-compile") or (sorted(glob.glob("/nix/store/*-luau-*/bin/luau-compile")) or ["luau-compile"])[-1]

def measure(path):
    stats = tempfile.mktemp(suffix=".json")
    subprocess.run([LC, "--codegennull", "-O2", "--record-stats=function", "--stats-file=" + stats, path],
                   check=True, stdout=subprocess.DEVNULL)
    d = json.load(open(stats)); os.remove(stats)
    d = next(iter(d.values())) if "codegen" not in d else d
    return d["codegen"], d["lowerStats"]["functions"]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--top", type=int, default=0)
    a = ap.parse_args()
    files = a.files
    if not files:
        out = tempfile.mkdtemp(prefix="imgui_native_")
        subprocess.run([sys.executable, os.path.join(ROOT, "tools", "bundle.py"), out], check=True, stdout=subprocess.DEVNULL)
        files = [os.path.join(out, "ImGui.luau"), os.path.join(out, "ImGuiWorker.client.luau")]
    ok = True
    for path in files:
        total, fns = measure(path)
        lmp = os.path.join(os.path.dirname(path), "ImGui.linemap.json")
        lm = json.load(open(lmp)) if os.path.basename(path) == "ImGui.luau" and os.path.exists(lmp) else []
        def loc(n):
            best = None
            for start, name in lm:
                if start <= n: best = (start, name)
            return (best[1], n - best[0] + 1) if best else (os.path.basename(path), n)
        over = total > BUDGET
        ok = ok and not over
        print("%s: %d bytes native (%d functions), %.0f%% of the Studio module limit, %d KB headroom%s" % (
            os.path.basename(path), total, len(fns), 100 * total / STUDIO_LIMIT, (STUDIO_LIMIT - total) // 1024,
            "  OVER BUDGET" if over else ""))
        if lm:
            byfile = collections.Counter()
            for f in fns: byfile[loc(f["line"])[0]] += f["asmSize"]
            for name, size in byfile.most_common(): print("  %8.1f KB  %s" % (size / 1024, name))
        for f in sorted(fns, key=lambda f: -f["asmSize"])[:a.top]:
            print("  %8.1f KB  %-40s %s:%d" % ((f["asmSize"] / 1024, f["name"] or "?") + loc(f["line"])))
    print("NATIVE OK" if ok else "NATIVE OVER")
    sys.exit(0 if ok else 1)

main()
