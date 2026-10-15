#!/usr/bin/env python3
# Bundles the root *.lua (library + imgui_demo.lua), backends/ and fonts/ into ONE ModuleScript: build/ImGui.luau
# --no-demo: library only (imgui_demo.lua left out, like not compiling imgui_demo.cpp)
# --target love: build/imgui_love.lua for LÖVE/LuaJIT instead (LÖVE backend, shims from the LÖVE backend's COMPAT section, @native stripped).
#                The default (roblox) build is unaffected by it.
# Why: ModuleScripts don't share globals, and the setfenv() alternative turns off Luau's fast paths / native codegen.
# Each source file becomes a function in __FILES; IM_INCLUDE(name) runs it once and caches the result.
# The module returns a table with every global the library defines (ImGui, ImVec2, ImGuiConfigFlags, ImGui_ImplRoblox, ...).
# Roblox target also writes ImGuiTyped.luau (types + require(script.Impl), see tools/gen_types.py).
#
# Build-time optimizations (token rewrites with minify.py's lexer: strings/comments are never touched, every source line
# stays on its line so linemap.json still maps errors). IMGUI_BUNDLE_NOOPT=1 turns all off, IMGUI_BUNDLE_NO_<X>=1 one:
#   A  hot library globals (most referenced names assigned at a file's top level) become bundle-level locals declared
#      before __FILES: every file's assignment/reference then hits an upvalue instead of GETGLOBAL. Fewer names for
#      LuaJIT (60 upvalues per function). Library globals can't be patched from outside (use the returned table).
#   B  enum folding: the bundle is loaded once headless (Luau CLI) to dump enum-like tables (all values numbers, never
#      written inside a function) and numeric constants assigned once at top level; reads `ImGuiCol.Text` / `FLT_MAX`
#      inside function bodies become `0 --[[ImGuiCol.Text]]`. Load-time (top-level) code is left alone.
#   C  `--@hoist` functions in the sources (pure numeric helpers: ImMin, ImMax, ImClamp, ...) are moved to the bundle top
#      as `local function`s (their source lines become blank) so Luau -O2 can inline them everywhere.
#   E  statement-form `IM_ASSERT(...)` becomes `assert(...)` (fast builtin); expression uses are left alone.
import os, re, sys, json, shutil, subprocess, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from minify import TOKEN

NO_DEMO = "--no-demo" in sys.argv
LOVE = False
if "--target" in sys.argv:
    i = sys.argv.index("--target"); LOVE = sys.argv[i + 1] == "love"; del sys.argv[i:i + 2]
sys.argv = [a for a in sys.argv if a != "--no-demo"]
OPT = {x: os.environ.get("IMGUI_BUNDLE_NOOPT") != "1" and os.environ.get("IMGUI_BUNDLE_NO_" + x) != "1" for x in "ABCE"}
# A limits: Luau 200 locals in the main chunk (+ helpers, __FILES, ...), 200 upvalues per function; LuaJIT 60 upvalues
# per function (margin left for nested functions that also capture file locals)
MAX_LOCALS, MAX_UPVALUES = 160, (45 if LOVE else 150)
BACKEND = "imgui_impl_love.lua" if LOVE else "imgui_impl_roblox.lua"
SKIP = {"imgui_impl_roblox.lua", "imgui_impl_roblox_fonts.lua"} if LOVE else {"imgui_impl_love.lua"}
FILES = {}
for d in (ROOT, os.path.join(ROOT, "backends"), os.path.join(ROOT, "fonts")):
    for f in sorted(os.listdir(d)):
        if f.endswith(".lua") and not (NO_DEMO and f == "imgui_demo.lua") and f not in SKIP:
            src = open(os.path.join(d, f)).read()
            if LOVE: src = re.sub(r"^@native$", "", src, flags=re.M)  # keep line numbers
            FILES[f] = src

ORIG = dict(FILES)  # for gen_types
ENTRY = ["imgui.lua", BACKEND] + ([] if NO_DEMO else ["imgui_demo.lua"])  # run order

names = set()
for src in FILES.values():
    names.update(re.findall(r"^function ([A-Za-z_]\w*)\s*\(", src, re.M))
    names.update(re.findall(r"^([A-Za-z_]\w*)\s*=[^=]", src, re.M))

# ---- lexer helpers ----
KW = set("and break do else elseif end false for function goto if in local nil not or repeat return then true until while".split())

def lex(src):
    """[(kind, text, start)] without whitespace/comments; kinds: name num str op."""
    toks, pos = [], 0
    while pos < len(src):
        m = TOKEN.match(src, pos)
        k = m.lastgroup
        if k in ("ceq", "seq"): k = "lcom" if m.group(0).startswith("--") else "lstr"
        if k not in ("ws", "lcom", "com"): toks.append(("str" if k == "lstr" else k, m.group(0), pos))
        pos = m.end()
    return toks

def fdepths(toks):
    """function nesting depth of every token (0 = runs at load time)"""
    st, fd, out = [], 0, []
    for k, t, _ in toks:
        out.append(fd)
        if k == "name":
            if t == "function": st.append(1); fd += 1
            elif t in ("if", "do", "repeat"): st.append(0)
            elif t in ("end", "until"): fd -= st.pop()
    assert not st, "unbalanced blocks"
    return out

def declared(toks):
    """names declared as locals / parameters / loop variables anywhere"""
    out, n = set(), len(toks)
    for i, (k, t, _) in enumerate(toks):
        j = None
        if t == "local": j = i + 2 if toks[i + 1][1] == "function" else i + 1
        elif t == "for": j = i + 1
        elif t == "function":
            j = i + 1
            while toks[j][1] != "(": j += 1
            j += 1
        while j is not None and j < n and toks[j][0] == "name" and toks[j][1] not in KW:
            out.add(toks[j][1])
            j += 1
            if j < n and toks[j][1] == ",": j += 1
            else: break
    return out

def apply(src, edits):
    for s, e, r in sorted(edits, reverse=True): src = src[:s] + r + src[e:]
    return src

def isref(toks, i):
    """toks[i] is a variable read/write (not a field name)"""
    return toks[i][0] == "name" and (i == 0 or toks[i - 1][1] not in (".", ":"))

def nexttext(toks, i): return toks[i + 1][1] if i + 1 < len(toks) else ""

# ---- C: --@hoist helpers ----
hoisted, hoisted_names = [], []
if OPT["C"]:
    for f, src in FILES.items():
        while "--@hoist\n" in src:
            s = src.index("--@hoist\n") + len("--@hoist\n")
            toks = lex(src[s:])
            depth, i = 0, 0
            while True:  # first `function` ... matching end
                t = toks[i][1]
                if t == "function" or t in ("if", "do", "repeat"): depth += 1
                elif t in ("end", "until"):
                    depth -= 1
                    if depth == 0: break
                i += 1
            e = s + toks[i][2] + 3
            text = src[s:e]
            m = re.search(r"^(local )?function ([A-Za-z_]\w*)", text, re.M)
            hoisted_names.append(m.group(2))
            hoisted.append(text[:m.start()] + "local function " + text[m.start() + len(m.group(0)) - len(m.group(2)):])
            src = src[:s - len("--@hoist\n")] + "\n" + re.sub(r"[^\n]", "", text) + src[e:]
        FILES[f] = src
HOIST_DEPS = "local type, mathMin, mathMax, mathFloor, mathCeil, bitOr, bitLShift = type, math.min, math.max, math.floor, math.ceil, bit32.bor, bit32.lshift"

# ---- E: statement IM_ASSERT -> assert ----
STMT_PREV_KW = {"end", "true", "false", "nil", "break", "then", "do", "else", "repeat"}
def rewrite_assert(src):
    toks, edits = lex(src), []
    for i, (k, t, p) in enumerate(toks):
        if t == "IM_ASSERT" and isref(toks, i) and nexttext(toks, i) == "(":
            pk, pt = (toks[i - 1][0], toks[i - 1][1]) if i else ("op", ";")
            if (pk == "name" and (pt not in KW or pt in STMT_PREV_KW)) or pk in ("num", "str") or pt in (")", "]", "}", ";", "..."):
                edits.append((p, p + len(t), "assert"))
    return apply(src, edits)

if OPT["E"]:
    FILES = {f: rewrite_assert(s) for f, s in FILES.items()}
    hoisted = [rewrite_assert(s) for s in hoisted]

# ---- B: enum / constant folding ----
LUAU = shutil.which("luau") or "/nix/store/2m2ja613nndihc8qm10f2rhq6znp1nh4-luau-0.734/bin/luau"

def header():
    return ["local __FILES, __LOADED = {}, {}",
            "function IM_INCLUDE(name)",
            "    local r = __LOADED[name]",
            "    if r == nil then r = __FILES[name](); if r == nil then r = true end; __LOADED[name] = r end",
            "    return r",
            "end", ""]

def numtext(s):
    v = float(s)
    if v != v or v in (float("inf"), float("-inf")) or (v == 0 and s.startswith("-")): return None
    r = str(int(v)) if v.is_integer() and abs(v) < 2 ** 53 else repr(v)
    return "(%s)" % r if v < 0 else r

def dump_values():
    """{name: number} and {name: {key: number}} of the loaded library (imgui.lua and what it includes)"""
    src = ["--!optimize 1"] + ([HOIST_DEPS] + hoisted if hoisted else []) + header()
    for name, s in sorted(FILES.items()): src += ["__FILES[%r] = function()" % name, s, "end"]
    src += ['IM_INCLUDE("imgui.lua")',
            'local function D(n, v) if type(v) == "number" then print("C", n, string.format("%.17g", v)) elseif type(v) == "table" then',
            '  for k, x in pairs(v) do print("T", n, type(k) == "string" and k or "?", type(x) == "number" and string.format("%.17g", x) or "?") end end end']
    src += ["D(%r, %s)" % (n, n) for n in sorted(names)]
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False) as fp: fp.write("\n".join(src))
    try:
        p = subprocess.run([LUAU, fp.name], capture_output=True, text=True, timeout=60)
    finally:
        os.unlink(fp.name)
    if p.returncode: raise RuntimeError("enum dump failed:\n" + p.stdout[-2000:] + p.stderr[-2000:])
    consts, tables = {}, {}
    for line in p.stdout.splitlines():
        a = line.split("\t")
        if a[0] == "C": consts[a[1]] = a[2]
        elif a[0] == "T": tables.setdefault(a[1], {})[a[2]] = a[3]
    tables = {n: t for n, t in tables.items() if "?" not in t and "?" not in t.values()}
    return consts, tables

def fold(files):
    consts, tables = dump_values()
    lexed = {f: lex(s) for f, s in files.items()}
    depth = {f: fdepths(t) for f, t in lexed.items()}
    # tables written inside a function, constants assigned more than once or not at top level: not foldable
    assigns = {}
    for f, toks in lexed.items():
        for i, (k, t, _) in enumerate(toks):
            if not isref(toks, i): continue
            if t in tables and depth[f][i] > 0:
                j = i + 1
                if nexttext(toks, i) == ".": j = i + 3
                elif nexttext(toks, i) == "[":
                    b = 0
                    while True:
                        b += {"[": 1, "]": -1}.get(toks[j][1], 0); j += 1
                        if b == 0: break
                if j < len(toks) and toks[j][1] == "=": tables.pop(t, None)
            if t in consts and nexttext(toks, i) == "=":
                assigns[t] = assigns.get(t, 0) + (1 if depth[f][i] == 0 else 2)
    consts = {n: v for n, v in consts.items() if assigns.get(n) == 1 and numtext(v)}
    out = {}
    for f, toks in lexed.items():
        shadow = declared(toks)
        edits = []
        for i, (k, t, p) in enumerate(toks):
            if depth[f][i] == 0 or not isref(toks, i) or t in shadow: continue
            if t in tables and nexttext(toks, i) == "." and i + 2 < len(toks):
                key = toks[i + 2][1]
                if key in tables[t] and numtext(tables[t][key]) and nexttext(toks, i + 2) not in ("=", ".", ":", "[", "(", "{") and toks[i + 3][0] != "str":
                    edits.append((p, toks[i + 2][2] + len(key), "%s --[[%s.%s]]" % (numtext(tables[t][key]), t, key)))
            elif t in consts and nexttext(toks, i) not in ("=", ".", ":", "[", "(", "{") and toks[i + 1][0] != "str":
                edits.append((p, p + len(t), "%s --[[%s]]" % (numtext(consts[t]), t)))
        out[f] = apply(files[f], edits)
    return out

if OPT["B"]:
    try:
        allf = dict(FILES); allf.update({"@hoist%d" % i: "local function __h()\n" + s + "\nend" for i, s in enumerate(hoisted)})
        allf = fold(allf)
        hoisted = [allf.pop("@hoist%d" % i)[len("local function __h()\n"):-len("\nend")] for i in range(len(hoisted))]
        FILES = allf
    except (OSError, RuntimeError) as e:
        if os.environ.get("IMGUI_BUNDLE_STRICT"): raise  # CI: a release must not silently lose the folding
        print("bundle.py: enum folding skipped (%s)" % str(e).strip()[:300], file=sys.stderr)

# ---- A: hot globals -> bundle locals ----
hot = []
if OPT["A"]:
    count, used = {}, []
    for src in FILES.values():
        toks = lex(src)
        used.append({t for i, (k, t, _) in enumerate(toks) if isref(toks, i)})
        for i, (k, t, _) in enumerate(toks):
            if t in names and isref(toks, i): count[t] = count.get(t, 0) + 1
    # greedy by reference count; each file function's upvalues (hoisted names it uses) stay <= MAX_UPVALUES
    taken = [len(u & set(hoisted_names + re.findall(r"\w+", HOIST_DEPS.split("=")[0]))) for u in used]
    for n in sorted((n for n in count if n not in hoisted_names), key=lambda n: (-count[n], n)):
        if len(hot) == MAX_LOCALS: break
        if all(taken[i] < MAX_UPVALUES for i, u in enumerate(used) if n in u):
            hot.append(n)
            taken = [c + (n in u) for c, u in zip(taken, used)]

out = ["--!optimize 2", "-- GENERATED by tools/bundle.py from *.lua, backends/, fonts/ - do not edit", ""]
if LOVE:
    out = ["-- GENERATED by tools/bundle.py --target love - do not edit", re.search(r"--@compat-begin\n(.*?)--@compat-end", open(os.path.join(ROOT, "backends", "imgui_impl_love.lua")).read(), re.S).group(1), ""]
if hot: out.append("local " + ", ".join(hot))
if hoisted: out += [HOIST_DEPS] + hoisted
out += header()
linemap = []  # (first bundle line, file) for error -> source mapping (tools/test/run.py)
for name, src in sorted(FILES.items()):
    out.append("__FILES[%r] = function()" % name)
    linemap.append((sum(x.count("\n") + 1 for x in out) + 1, name))
    out.append(src.rstrip("\n"))
    out.append("end")
    out.append("")
for name in ENTRY:
    out.append("IM_INCLUDE(%r)" % name)
out.append("")
out.append("return {")
for n in sorted(names):
    out.append("    %s = %s," % (n, n))
out.append("}")

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build")
os.makedirs(OUT, exist_ok=True)
NAME = "imgui_love.lua" if LOVE else "ImGui.luau"
open(os.path.join(OUT, NAME), "w").write("\n".join(out) + "\n")
json.dump(linemap, open(os.path.join(OUT, NAME.rsplit(".", 1)[0] + ".linemap.json"), "w"))
if not LOVE:
    from gen_types import wrapper
    open(os.path.join(OUT, "ImGuiTyped.luau"), "w").write(wrapper(ORIG))
print("wrote build/%s (%d files, %d exports)" % (NAME, len(FILES), len(names)))
