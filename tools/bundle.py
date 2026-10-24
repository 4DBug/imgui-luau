#!/usr/bin/env python3
# Bundles the root *.lua (library + imgui_demo.lua), the target's backend folder (backends/roblox/*.lua, or
# backends/love/*.lua) and fonts/ (Roblox) into ONE ModuleScript: build/ImGui.luau
# --no-demo: library only (imgui_demo.lua left out, like not compiling imgui_demo.cpp)
# --target love: build/imgui_love.lua for LÖVE/LuaJIT instead (LÖVE backend, shims from the LÖVE backend's COMPAT section, @native stripped).
#                The default (roblox) build is unaffected by it.
# Why: ModuleScripts don't share globals, and the setfenv() alternative turns off Luau's fast paths / native codegen.
# Each source file becomes a function in __FILES; IM_INCLUDE(name) runs it once and caches the result.
# The module returns a table with every global the library defines (ImGui, ImVec2, ImGuiConfigFlags, ImGui_ImplRoblox, ...).
# Roblox target also writes ImGuiTyped.luau (types + require(script.Impl), see tools/gen_types.py) and
# ImGuiWorker.client.luau: the parallel raster Actor LocalScript (backends/roblox/worker.luau with its
# `require(...Raster...)` line replaced by backends/roblox/raster.lua itself: self-contained, no require).
# The Roblox backend's modules are inlined into one function (see "Backend modules" below).
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
#   L  (Roblox) library-internal `ImGui.Foo` reads inside function bodies become `ImGui_Foo`, a local of the file's
#      __FILES function or of a wrapper around it (the file's most used names, within the 200 locals / upvalues
#      limits; the rest stays ImGui.Foo). Luau's inline cache only
#      remembers hash slots < 256 and ImGui has ~1000 keys: most ImGui.Foo lookups missed it. Each file registers a
#      binder (`ImGui_Foo = ImGui.Foo`, ...) that IM_INCLUDE runs after every file it loads, so they are set before
#      any user code runs. Only names assigned exactly once, at load time, are localized (checked here); ImGui.Foo
#      stays set (public table unchanged). An app that replaces ImGui.Foo no longer intercepts the library's own
#      calls, except for the names in L_PATCHABLE (hooked by tests/apps: those stay table lookups).
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
OPT = {x: os.environ.get("IMGUI_BUNDLE_NOOPT") != "1" and os.environ.get("IMGUI_BUNDLE_NO_" + x) != "1" for x in "ABCEL"}
# A limits: Luau 200 locals in the main chunk (A's hot globals + C's hoisted functions <= MAX_LOCALS, + helpers, __FILES,
# ...), 200 upvalues per function; LuaJIT 60 upvalues per function (margin left for nested functions that also capture
# file locals)
MAX_LOCALS, MAX_UPVALUES = 169, (45 if LOVE else 150)
TARGET = "love" if LOVE else "roblox"
BACKEND = "imgui_impl_%s.lua" % TARGET
BACKEND_DIR = os.path.join(ROOT, "backends", TARGET)  # every *.lua in it is bundled (*.luau, e.g. the worker, is not)
FILES = {}
for d in [ROOT, BACKEND_DIR] + ([] if LOVE else [os.path.join(ROOT, "fonts")]):
    for f in sorted(os.listdir(d)):
        if f.endswith(".lua") and not (NO_DEMO and f == "imgui_demo.lua"):
            src = open(os.path.join(d, f)).read()
            if LOVE: src = re.sub(r"^@native$", "", src, flags=re.M)  # keep line numbers
            FILES[f if d != BACKEND_DIR or f == BACKEND else TARGET + "/" + f] = src

# Backend modules (backends/<target>/*.lua besides the main file, keyed "<target>/x.lua") are inlined into the main
# file's __FILES function: `local X = IM_INCLUDE("<target>/x.lua")` lines become blank (X is declared once at the top of
# the function), each module body goes in its own do ... end in dependency order, its final `return M` becomes `X = M`.
# Cross-module access is then a local of the same function, no IM_INCLUDE at load time. In source, the same files work
# with plain IM_INCLUDE (each a function returning its table).
INCLUDE = re.compile(r'^local (\w+) = IM_INCLUDE\("(%s/\w+\.lua)"\)[ \t]*$' % TARGET, re.M)
MODULES, EXPORT = [], {}  # inline order, key -> local name
def visit(f, stack=()):
    assert f not in stack, "backend modules: circular IM_INCLUDE %s" % " -> ".join(stack + (f,))
    for name, key in INCLUDE.findall(FILES[f]):
        assert EXPORT.setdefault(key, name) == name, "%s is included as both %s and %s" % (key, EXPORT[key], name)
        if key not in MODULES: visit(key, stack + (f,)); MODULES.append(key)
visit(BACKEND)
unused = [f for f in FILES if f.startswith(TARGET + "/") and f not in MODULES]
assert not unused, "backend modules never included: %s" % unused
GROUP = {f: BACKEND for f in MODULES}  # file -> __FILES function it is emitted in

def inline_module(key, src):
    src = INCLUDE.sub("", src)
    m = re.search(r"^return (\w+)[ \t]*\n*\Z", src, re.M)
    assert m and m.group(1) != EXPORT[key], "%s must end with `return M` (a name other than %s)" % (key, EXPORT[key])
    return src[:m.start()] + "%s = %s\n" % (EXPORT[key], m.group(1))

ORIG = dict(FILES)  # for gen_types
ENTRY = ["imgui.lua", BACKEND] + ([] if NO_DEMO else ["imgui_demo.lua"])  # run order

names = set()
for src in FILES.values():
    names.update(re.findall(r"^function ([A-Za-z_]\w*)\s*\(", src, re.M))
    names.update(re.findall(r"^([A-Za-z_]\w*)\s*=[^=]", src, re.M))
assert not names & set(EXPORT.values()), "backend module names clash with globals: %s" % (names & set(EXPORT.values()))

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
LUAU = shutil.which("luau") or (sorted(__import__("glob").glob("/nix/store/*-luau-*/bin/luau")) or ["luau"])[-1]

def header(bind=False):
    return ["local __FILES, __LOADED%s = {}, {}%s" % ((", __BIND", ", {}") if bind else ("", "")),
            "function IM_INCLUDE(name)",
            "    local r = __LOADED[name]",
            "    if r == nil then r = __FILES[name](); if r == nil then r = true end; __LOADED[name] = r%s end" % ("; for i = 1, #__BIND do __BIND[i]() end" if bind else ""),
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
    count, used = {}, {}
    for f, src in FILES.items():
        toks = lex(src)
        used.setdefault(GROUP.get(f, f), set()).update(t for i, (k, t, _) in enumerate(toks) if isref(toks, i))
        for i, (k, t, _) in enumerate(toks):
            if t in names and isref(toks, i): count[t] = count.get(t, 0) + 1
    # greedy by reference count; each file function's upvalues (hoisted names it uses) stay <= MAX_UPVALUES
    used = list(used.values())
    taken = [len(u & set(hoisted_names + re.findall(r"\w+", HOIST_DEPS.split("=")[0]))) for u in used]
    for n in sorted((n for n in count if n not in hoisted_names), key=lambda n: (-count[n], n)):
        if len(hot) + len(hoisted_names) >= MAX_LOCALS: break
        if all(taken[i] < MAX_UPVALUES for i, u in enumerate(used) if n in u):
            hot.append(n)
            taken = [c + (n in u) for c, u in zip(taken, used)]

# ---- L: ImGui.Foo reads in function bodies -> per-file locals ----
# (L only rewrites `ImGui.Foo` reads: MT.* methods and other globals, e.g. what backends/roblox/patches.lua replaces at
# load time - MT.ImFont.RenderText, MT.ImDrawList.AddText, ImFontCalcTextSizeXY - are never copied. Assignments in
# backend modules count too: a name set in two places is not localized.)
L_PATCHABLE = re.compile(r"(Begin|End|TreeNode\w*|CollapsingHeader|ItemAdd|ItemHoverable|ItemSize|BeginTabItem|ShowDemoWindow)$")
L_LOCALS, L_UPVALUES = 200 - 20 - 10, 200 - 5  # Luau limits per function, minus the registers check's 20, minus margin
localized = {}  # __FILES function -> ([Foo, ...] in a wrapper function, [Foo, ...] in the function itself)
def imgui_read(toks, d, i, ok):
    """toks[i] starts an `ImGui.Foo` read (Foo in ok) inside a function body"""
    return toks[i][1] == "ImGui" and d[i] > 0 and isref(toks, i) and toks[i - 1][1] != "function" and nexttext(toks, i) == "." and toks[i + 2][1] in ok and nexttext(toks, i + 2) != "="
def nlocal(toks, i):
    """names declared by the `local` at toks[i]"""
    if nexttext(toks, i) == "function": return 1
    n, j = 1, i + 2
    while nexttext(toks, j - 1) == "," : n += 1; j += 2
    return n
if OPT["L"] and not LOVE:
    lexed = {f: lex(s) for f, s in FILES.items()}
    sets, idents = {}, set()
    for f, toks in lexed.items():
        d = fdepths(toks)
        idents.update(t for k, t, _ in toks if k == "name")
        for i, (k, t, p) in enumerate(toks):
            if t != "ImGui" or not isref(toks, i): continue
            nx = nexttext(toks, i)
            if nx != ".":
                assert nx == "=" and d[i] == 0 and nexttext(toks, i + 1) == "{", "L: %s: ImGui used as a value (%r): can't prove single assignment of its fields" % (f, nx)
                continue
            key, after = toks[i + 2][1], nexttext(toks, i + 2)
            j = i + 3  # `ImGui.Foo, x = ...` (multiple assignment)? walk a target list
            while after == "," and j < len(toks) and (toks[j][0] == "name" or toks[j][1] in (".", ",")): j += 1
            if i > 0 and toks[i - 1][1] == "function": sets.setdefault(key, []).append((f, d[i - 1]))
            elif after == "=" or (after == "," and j < len(toks) and toks[j][1] == "="): sets.setdefault(key, []).append((f, d[i]))
    ok = {n for n, w in sets.items() if len(w) == 1 and w[0][1] == 0 and not L_PATCHABLE.match(n)}
    clash = {"ImGui_" + n for n in ok} & idents
    assert not clash, "L: local names clash with source identifiers: %s" % sorted(clash)
    # where the locals go (most used names first): the __FILES function itself (room left next to its own top-level
    # locals) and, when that's not enough, a wrapper function around it first (`(function() local ImGui_Foo, ...
    # return function() <file> end end)()`: they are upvalues of the file function, next to the bundle-level A/C locals).
    # The rest stays ImGui.Foo (small tables `ImGui__1.Foo` for them, always cache hits, measured no faster).
    upvals = set(hot + hoisted_names + re.findall(r"\w+", HOIST_DEPS.split("=")[0]))
    count, nlocals, nupvals = {}, {}, {}
    for f, toks in lexed.items():
        fn, d = GROUP.get(f, f), fdepths(toks)
        nlocals[fn] = nlocals.get(fn, 0) + sum(nlocal(toks, i) for i in range(len(toks)) if toks[i][1] == "local" and d[i] == 0)
        nupvals.setdefault(fn, set()).update(t for i, (k, t, _) in enumerate(toks) if t in upvals and isref(toks, i))
        if "ImGui" in declared(toks): count[fn] = None
        if count.get(fn, {}) is None: continue
        c = count.setdefault(fn, {})
        for i in range(len(toks)):
            if imgui_read(toks, d, i, ok): c[toks[i + 2][1]] = c.get(toks[i + 2][1], 0) + 1
    if BACKEND in nlocals: nlocals[BACKEND] += len(MODULES)
    for fn, c in count.items():
        c = sorted(c or (), key=lambda n: (-c[n], n))
        inner = max(0, L_LOCALS - nlocals[fn])
        outer = 0 if fn == BACKEND or len(c) <= inner else min(L_LOCALS, L_UPVALUES - len(nupvals[fn]))  # (registers check: the backend's function line stays plain)
        if c: localized[fn] = (sorted(c[:outer]), sorted(c[outer:outer + inner]))
    for f, toks in lexed.items():
        sel = set().union(*localized.get(GROUP.get(f, f), ()))
        if not sel: continue
        d = fdepths(toks)
        FILES[f] = apply(FILES[f], [(toks[i][2], toks[i + 2][2] + len(toks[i + 2][1]), "ImGui_" + toks[i + 2][1]) for i in range(len(toks)) if imgui_read(toks, d, i, sel)])

out = ["--!optimize 2", "-- GENERATED by tools/bundle.py from *.lua, backends/, fonts/ - do not edit", ""]
if LOVE:
    out = ["-- GENERATED by tools/bundle.py --target love - do not edit", re.search(r"--@compat-begin\n(.*?)--@compat-end", open(os.path.join(BACKEND_DIR, BACKEND)).read(), re.S).group(1), ""]
if hot: out.append("local " + ", ".join(hot))
if hoisted: out += [HOIST_DEPS] + hoisted
out += header(bool(localized))
linemap = []  # (first bundle line, file) for error -> source mapping (tools/test/run.py)
def nextline(): return sum(x.count("\n") + 1 for x in out) + 1
for name, src in sorted(FILES.items()):
    if name in GROUP: continue
    outer, inner = localized.get(name, ((), ()))
    out.append("__FILES[%r] = %sfunction()" % (name, "(" if outer else ""))
    for ns in (outer, inner):  # declared + bound (now and after every IM_INCLUDE: load-time calls into other files)
        if not ns: continue
        out.append("local " + ", ".join("ImGui_" + n for n in ns))
        out.append("__BIND[#__BIND + 1] = function() if ImGui then " + " ".join("ImGui_%s = ImGui.%s" % (n, n) for n in ns) + " end end; __BIND[#__BIND]()")
        if ns is outer: out.append("return function()")
    if name == BACKEND and MODULES:
        out.append("local " + ", ".join(EXPORT[k] for k in MODULES))
        for k in MODULES:
            out.append("do")
            linemap.append((nextline(), k))
            out.append(inline_module(k, FILES[k]).rstrip("\n"))
            out.append("end")
        src = INCLUDE.sub("", src)
    linemap.append((nextline(), name))
    out.append(src.rstrip("\n"))
    out.append("end end)()" if outer else "end")
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
    worker = open(os.path.join(BACKEND_DIR, "worker.luau")).read()
    req = re.search(r"^local Raster = require\(.*\)$", worker, re.M)
    assert req, "worker: no `local Raster = require(...)` line"
    raster = ORIG["roblox/raster.lua"].rstrip("\n")
    open(os.path.join(OUT, "ImGuiWorker.client.luau"), "w").write(
        "--!optimize 2\n-- GENERATED by tools/bundle.py from backends/roblox/worker.luau + raster.lua - do not edit\n"
        + worker[:req.start()] + "local Raster = (function()\n" + raster + "\nend)()" + worker[req.end():])
print("wrote build/%s (%d files, %d exports%s)" % (NAME, len(FILES), len(names), ", %d ImGui.* localized" % sum(len(a) + len(b) for a, b in localized.values()) if localized else ""))
