#!/usr/bin/env python3
# Compares the port against upstream Dear ImGui (tools/test/upstream/*) and writes docs/PORT_STATUS.txt.
#   python3 tools/compare_upstream.py            # print summary, write docs/PORT_STATUS.txt
# Ported %:     upstream functions (by qualified name, overloads merged) that have a port definition; enum values; struct fields;
#               public/internal API declarations in imgui.h / imgui_internal.h (namespace ImGui).
# Similarity %: for each ported function, both bodies are normalized to a common token stream (comments/types/punctuation
#               dropped, C++ operators and names mapped to Lua: -> :: . ! && || _Flag) and compared with difflib ratio.
#               File figures are weighted by upstream body size. Matching is by name, so it's an estimate, not a proof.
# Excluded from the %: C++-only (operators, destructors), #if 0, IMGUI_DISABLE_OBSOLETE_FUNCTIONS, OS-specific (#ifdef _WIN32...),
#               test engine. They're listed separately in the report.
import os, re, sys
from difflib import SequenceMatcher
from fnmatch import fnmatchcase
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from minify import TOKEN as LUA_TOKEN

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UP = os.path.join(ROOT, "tools", "test", "upstream")
CPP_FILES = ["imgui.cpp", "imgui_widgets.cpp", "imgui_draw.cpp", "imgui_tables.cpp", "imgui_demo.cpp", "imgui.h", "imgui_internal.h"]
PORT_FILES = sorted(f for f in os.listdir(ROOT) if f.endswith(".lua"))
LUA_CLASS_ALIAS = {"IM_RECT": "ImRect", "IM_VECTOR": "ImVector", "IM_POOL": "ImPool", "IMGUI_VIEWPORT_P": "ImGuiViewportP",
                   "ImGuiTextBufferMT": "ImGuiTextBuffer", "IMGUI_TEXT_INDEX": "ImGuiTextIndex", "IM_PAYLOAD": "ImGuiPayload",
                   "DN": "ImGuiDockNode", "IM_VTXBUF": "ImVector"}

# ---------------------------------------------------------------------------------------------------------------------
# Intentional Lua replacements: [=] rows, not counted as missing. (glob over the upstream key "Class::name" / "Struct::field",
# reason, regex that must match the port sources - if the port's mechanism disappears, the entry falls back to [ ] / missing).
# Only applies when no same-named port definition / field exists.
# ---------------------------------------------------------------------------------------------------------------------
REPLACED = [
    # functions
    ("ImGuiStorage::*", "Lua table keyed by ID (e.g. window.StateStorage = {})", r"StateStorage\s*=\s*\{\}"),
    ("ImGuiStoragePair::*", "Lua table keyed by ID", r"StateStorage\s*=\s*\{\}"),
    ("PairComparerByID", "table.sort over Lua table keys", r"table\.sort\("),
    ("ImStr*", "Lua string library (string.find/sub/lower, immutable strings)", r"string\.find\("),
    ("ImMemdup", "Lua strings/tables are values, no copy needed", r"string\.find\("),
    ("ImFormatString*", "string.format", r"ImFormatString\s*=\s*string\.format"),
    ("ImText*Utf8*", "strings stay UTF-8 bytes: ImStd.ImTextCharFromUtf8 decoder + utf8 library", r"function ImStd\.ImTextCharFromUtf8"),
    ("MallocWrapper", "GC; IM_ALLOC = ImGui.MemAlloc", r"IM_ALLOC\s*=\s*ImGui\.MemAlloc"),
    ("FreeWrapper", "GC; IM_ALLOC = ImGui.MemAlloc", r"IM_ALLOC\s*=\s*ImGui\.MemAlloc"),
    ("ImGui::GetAllocatorFunctions", "GC, no allocator to query", r"IM_ALLOC\s*=\s*ImGui\.MemAlloc"),
    ("ImFileWrite", "no filesystem on Roblox: SaveIniSettingsToDisk is a no-op, use SaveIniSettingsToMemory", r"Roblox: no disk"),
    ("ImSwap", "Lua multiple assignment a, b = b, a", r"\b([\w.]+), ([\w.]+) = \2, \1\b"),
    ("ImGui::DebugCheckVersionAndDataLayout", "C++ ABI / sizeof check", None),
    ("TableSettingsCalcChunkSize", "sizeof; table settings are a plain ImVector", r"SettingsTables\s*=\s*ImVector\(\)"),
    ("ImVector::size", "v.Size field", r"function IM_VECTOR:"),
    ("ImVector::capacity", "v.Capacity field", r"function IM_VECTOR:"),
    ("ImVector::front", "v.Data[1]", r"function IM_VECTOR:"),
    ("ImVector::begin", "v.Data / v:iter()", r"function IM_VECTOR:iter\("),
    ("ImVector::end", "v.Data / v:iter()", r"function IM_VECTOR:iter\("),
    ("ImVector::size_in_bytes", "sizeof", None),
    ("ImVector::max_size", "sizeof", None),
    ("ImVector::clear_destruct", "GC: clear_delete / clear", r"function IM_VECTOR:clear_delete\("),
    ("ImVector::find", "find_index (no element pointers)", r"function IM_VECTOR:find_index\("),
    ("ImSpan::*", "plain Lua tables (e.g. table.Columns = {})", r"Columns = \{\}, ColumnsSize = 0"),
    ("ImSpanAllocator::*", "plain Lua tables, no arena", r"Columns = \{\}, ColumnsSize = 0"),
    ("ImStableVector::*", "ImVector (Lua references are stable)", r"BakedPool\s*=\s*ImVector\(\)"),
    ("ImChunkStream::*", "plain ImVector of settings tables", r"SettingsTables\s*=\s*ImVector\(\)"),
    ("ImPool::GetAliveCount", "pool.AliveCount field", r"\.AliveCount\)"),
    ("ImPool::GetBufSize", "pool.BufSize field / GetMapSize()", r"function IM_POOL:GetMapSize\(\) return self\.BufSize"),
    ("ImPool::TryGetMapData", "GetByIndex (removed slots hold false)", r"function IM_POOL:GetByIndex\("),
    ("ImGuiTextBuffer::begin", "chunk-list string builder: c_str()", r"function ImGuiTextBufferMT:c_str\("),
    ("ImGuiTextBuffer::end", "chunk-list string builder: c_str()", r"function ImGuiTextBufferMT:c_str\("),
    ("ImGuiTextBuffer::resize", "chunk-list string builder, no byte buffer", r"function ImGuiTextBufferMT:c_str\("),
    ("ImGuiTextBuffer::reserve", "chunk-list string builder, no byte buffer", r"function ImGuiTextBufferMT:c_str\("),
    ("ImGuiTextBuffer::appendfv", "appendf(fmt, ...) (Lua varargs)", r"function ImGuiTextBufferMT:appendf\("),
    ("ImGuiTextIndex::append", "debug log keeps a Lua line list (g.DebugLogLines)", r"g\.DebugLogLines\s*="),
    # struct fields (ImSpan*/ImStableVector/ImGuiStoragePair fields: covered by the globs above)
    ("ImGuiTextBuffer::EmptyString", "c_str() of an empty chunk list", r"function ImGuiTextBufferMT:c_str\("),
    ("ImGuiWindow::NameBufLen", "window.Name is an immutable Lua string", None),
    ("ImGuiTextFilterItem::Begin", "item.Text substring", r"Text = string\.sub\(buf, b, e - 1\)"),
    ("ImGuiTextFilterItem::Len", "item.Text substring", r"Text = string\.sub\(buf, b, e - 1\)"),
    ("ImDrawVert::uv", "vertices packed into VtxBuffer.Buf (VTX_STRIDE bytes per vertex)", r"VTX_STRIDE\s*=\s*\d+"),
    ("ImDrawVert::col", "vertices packed into VtxBuffer.Buf (VTX_STRIDE bytes per vertex)", r"VTX_STRIDE\s*=\s*\d+"),
    ("ImGuiContext::DebugLogIndex", "Lua line list g.DebugLogLines", r"g\.DebugLogLines\s*="),
    ("ImGuiContext::TempKeychordName", "GetKeyChordName returns a Lua string", r"\.\. \(\(key ~= ImGuiKey\.None"),
    ("ImGuiContext::DragDropPayloadBuf*", "payload.Data holds the Lua value", r"payload\.Data = data"),
    ("ImGuiTabBar::TabsNames", "names stored on the tab (tab.Name)", r"Tab names are stored on the tab itself"),
]

# ---------------------------------------------------------------------------------------------------------------------
# C++ side
# ---------------------------------------------------------------------------------------------------------------------
CPP_TOKEN = re.compile(r"""
  (?P<nl>\n)
| (?P<ws>[ \t\r\f\v]+|\\\n)
| (?P<com>//[^\n]*|/\*.*?\*/)
| (?P<pp>\#(?:[^\n\\]|\\.|\\\n)*)
| (?P<str>(?:u8|u|U|L)?"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')
| (?P<num>0[xX][0-9a-fA-F']+[uUlL]*|(?:\d[\d']*\.?\d*|\.\d+)(?:[eE][+-]?\d+)?[fFuUlL]*)
| (?P<name>[A-Za-z_]\w*)
| (?P<op>->\*?|::|<<=|>>=|<<|>>|&&|\|\||==|!=|<=|>=|\+\+|--|[-+*/%&|^]=|\.\.\.|.)
""", re.S | re.X)

EXCLUDE_PP = [("if0", re.compile(r"^\s*#\s*if\s+0\b")),
              ("obsolete", re.compile(r"#\s*ifndef\s+IMGUI_DISABLE_OBSOLETE_FUNCTIONS|#\s*if\s+!defined\(IMGUI_DISABLE_OBSOLETE")),
              ("os-specific", re.compile(r"_WIN32|__APPLE__|__linux__|_MSC_VER|__EMSCRIPTEN__|IMGUI_DISABLE_WIN32|__ANDROID__|_XBOX|__MINGW")),
              ("test-engine", re.compile(r"IMGUI_ENABLE_TEST_ENGINE"))]

def cpp_tokens(src):
    """[(kind, text, line, excl)] without whitespace/comments; excl = exclusion tag from enclosing #if, or None."""
    out, line, stack, sections = [], 1, [], []
    for m in CPP_TOKEN.finditer(src):
        kind, text = m.lastgroup, m.group(0)
        if kind == "nl": line += 1; continue
        if kind == "com":
            s = re.match(r"//\s*\[SECTION\]\s*(.+)", text)
            if s: sections.append((line, s.group(1).strip()))
            line += text.count("\n"); continue
        if kind == "ws": line += text.count("\n"); continue
        if kind == "pp":
            d = re.match(r"#\s*(\w+)", text); d = d.group(1) if d else ""
            if d in ("if", "ifdef", "ifndef"):
                stack.append(next((t for t, r in EXCLUDE_PP if r.search(text)), None))
            elif d in ("else", "elif") and stack:
                stack[-1] = None if stack[-1] in ("if0", "obsolete") else stack[-1]  # #else of `#if 0` / obsolete is the live path
            elif d == "endif" and stack:
                stack.pop()
            line += text.count("\n"); continue
        out.append((kind, text, line, next((x for x in reversed(stack) if x), None)))
    return out, sections

CPP_MACROS = {"IM_MSVC_RUNTIME_CHECKS_OFF", "IM_MSVC_RUNTIME_CHECKS_RESTORE"}  # argument-less macro lines, no trailing ';'
CTRL = {"if", "for", "while", "switch", "catch", "sizeof", "return", "alignof", "decltype", "IM_ASSERT", "defined"}

def match_back(toks, i, close, open_):
    depth = 0
    while i >= 0:
        t = toks[i][1]
        if t == close: depth += 1
        elif t == open_:
            depth -= 1
            if depth == 0: return i
        i -= 1
    return -1

def match_fwd(toks, i):
    depth = 0
    pairs = {"{": "}", "(": ")", "[": "]"}
    open_ = toks[i][1]; close = pairs[open_]
    while i < len(toks):
        t = toks[i][1]
        if t == open_: depth += 1
        elif t == close:
            depth -= 1
            if depth == 0: return i
        i += 1
    return len(toks) - 1

def func_head(toks, i):
    """toks[i] is '{'. If it opens a function body, return (class, name, name_tok_index, cpp_only) else None."""
    j = i - 1
    while j >= 0 and toks[j][1] in ("const", "noexcept", "override", "final", "IM_FMTARGS", "IM_FMTLIST"):
        j -= 1
    if j >= 0 and toks[j][1] == ")" and toks[match_back(toks, j, ")", "(") - 1][1] in ("IM_FMTARGS", "IM_FMTLIST"):
        j = match_back(toks, j, ")", "(") - 2
    # constructor initializer list:  Foo::Foo(...) : a(1), b{2} {
    k = j
    while k >= 0 and toks[k][1] in (")", "}"):
        o = match_back(toks, k, toks[k][1], "(" if toks[k][1] == ")" else "{")
        if o <= 1: break
        if toks[o - 2][1] in (",",) or (toks[o - 2][1] == ":" ):
            if toks[o - 2][1] == ":": j = o - 3; break
            k = o - 3; continue
        break
    if j < 0 or toks[j][1] != ")": return None
    o = match_back(toks, j, ")", "(")
    if o <= 0: return None
    n = o - 1
    name = toks[n][1]
    cpp_only = False
    if toks[n - 1][1] == "operator" or (n >= 1 and toks[n][0] == "op" and toks[n - 1][1] == "operator"):
        return (None, "operator" + name, n, True)
    if toks[n][0] == "op" and n >= 2 and toks[n - 1][1] == "operator": return (None, "operator", n, True)
    if toks[n][0] != "name" or name in CTRL: return None
    if toks[n - 1][1] == "~": cpp_only = True; name = "~" + name
    cls = None
    if toks[n - 1][1] == "::" or (cpp_only and toks[n - 2][1] == "::"):
        q = n - 2 if not cpp_only else n - 3
        cls = toks[q][1]
    if toks[n - 1][1] == "operator": return (cls, "operator", n, True)
    return (cls, name, n, cpp_only)

class UpFunc:
    def __init__(s, file, cls, name, line, body, section, excl):
        s.file, s.cls, s.name, s.line, s.body, s.section, s.excl = file, cls, name, line, body, section, excl
    @property
    def key(s): return "%s::%s" % (s.cls, s.name) if s.cls else s.name

def parse_cpp(fname):
    src = open(os.path.join(UP, fname), encoding="utf-8", errors="replace").read()
    toks, sections = cpp_tokens(src)
    funcs, enums, structs, decls = [], {}, {}, {}  # decls: namespace ImGui declarations (name -> line)

    def section_at(line):
        cur = ""
        for l, s in sections:
            if l <= line and l > 120: cur = s  # skip the index at the top of each file
        return cur

    def scan(a, b, cls, ns):
        i = a
        stmt_start = a
        while i < b:
            k, t, line, excl = toks[i]
            if t == "{":
                head = func_head(toks, i)
                e = match_fwd(toks, i)
                pre = [x[1] for x in toks[stmt_start:i]]
                if head:
                    hc, hn, ni, cpp_only = head
                    c = hc or cls
                    if cls and hn == cls: c = cls  # inline ctor in struct
                    ex = "c++-only" if cpp_only or hn.startswith("~") else toks[ni][3]
                    if c and hn == c and fname.endswith(".h") and e - i < 4: ex = ex  # trivial ctor kept
                    funcs.append(UpFunc(fname, c, hn, toks[ni][2], toks[i + 1:e], section_at(toks[ni][2]), ex))
                elif "namespace" in pre:
                    q = pre.index("namespace")
                    scan(i + 1, e, cls, (pre[q + 1] if len(pre) > q + 1 else ""))
                elif "enum" in pre:
                    nm = next((x for x in pre[pre.index("enum") + 1:] if re.match(r"[A-Za-z_]\w*$", x) and x not in ("class", "int")), None)
                    vals, j, depth = [], i + 1, 0
                    expect = True
                    while j < e:
                        tt = toks[j][1]
                        if tt in "([{": depth += 1
                        elif tt in ")]}": depth -= 1
                        elif depth == 0 and tt == ",": expect = True
                        elif expect and depth == 0 and toks[j][0] == "name":
                            vals.append((tt, toks[j][2], toks[j][3])); expect = False
                        j += 1
                    if nm: enums[nm] = (vals, line, section_at(line))
                elif any(x in ("struct", "class", "union") for x in pre) and "=" not in pre:
                    kw = max(q for q, x in enumerate(pre) if x in ("struct", "class", "union"))  # skips macro lines / template<...> before it
                    names = [x for x in pre[kw:] if re.match(r"[A-Za-z_]\w*$", x) and x not in ("struct", "class", "union", "IMGUI_API", "typedef", "final", "public", "private", "alignas")]
                    nm = names[0] if names else cls
                    if nm and "union" not in pre: structs.setdefault(nm, ([], line, section_at(line)))
                    scan(i + 1, e, nm, ns)
                    if nm and pre[:1] != ["union"] and toks[e + 1][1] != ";" and toks[e + 1][0] == "name" and cls:
                        pass
                i = e + 1
                if i < b and toks[i][1] == ";": i += 1
                stmt_start = i
                continue
            if t == ";":
                st = toks[stmt_start:i]
                txt = [x[1] for x in st]
                if txt and txt[0] in ("public", "private", "protected") and len(txt) > 1 and txt[1] == ":": st, txt = st[2:], txt[2:]
                while txt and txt[0] in CPP_MACROS: st, txt = st[1:], txt[1:]
                if txt and ns == "ImGui" and cls is None and "(" in txt and txt[0] not in ("typedef", "struct", "enum", "using"):
                    p = txt.index("(")
                    if p > 0 and st[p - 1][0] == "name" and txt[p - 1] not in CTRL:
                        decls.setdefault(txt[p - 1], (st[p - 1][2], st[p - 1][3], section_at(st[p - 1][2])))
                elif txt and cls and txt[0] not in ("typedef", "friend", "static", "using", "enum", "struct", "class", "template"):
                    eq = txt.index("=") if "=" in txt else len(txt)
                    pa = txt.index("(") if "(" in txt else len(txt)
                    if pa >= eq:  # not a method declaration
                        depth = 0
                        for j, x in enumerate(txt[:eq] + [";"]):
                            if x in ("<", "(", "["): depth += 1
                            elif x in (">", ")", "]"): depth -= 1
                            elif depth == 0 and x in (",", ";", ":") or (depth == 0 and x == "[" ):
                                if j > 0 and re.match(r"[A-Za-z_]\w*$", txt[j - 1]) and txt[j - 1] not in ("const", "unsigned", "int", "float"):
                                    structs.setdefault(cls, ([], 0, ""))[0].append((txt[j - 1], st[j - 1][2], st[j - 1][3]))
                            if x == "[" and depth == 1 and j > 0 and re.match(r"[A-Za-z_]\w*$", txt[j - 1]):
                                structs.setdefault(cls, ([], 0, ""))[0].append((txt[j - 1], st[j - 1][2], st[j - 1][3]))
                        if eq < len(txt) and re.match(r"[A-Za-z_]\w*$", txt[eq - 1]):
                            structs.setdefault(cls, ([], 0, ""))[0].append((txt[eq - 1], st[eq - 1][2], st[eq - 1][3]))
                stmt_start = i + 1
            i += 1
    scan(0, len(toks), None, "")
    for k in structs:  # dedupe fields
        seen, out = set(), []
        for f in structs[k][0]:
            if f[0] not in seen: seen.add(f[0]); out.append(f)
        structs[k] = (out,) + structs[k][1:]
    return funcs, enums, structs, decls

# ---------------------------------------------------------------------------------------------------------------------
# Lua side
# ---------------------------------------------------------------------------------------------------------------------
def lua_tokens(src):
    out, line, pos = [], 1, 0
    while pos < len(src):
        m = LUA_TOKEN.match(src, pos)
        kind, text = m.lastgroup, m.group(0)
        if kind in ("ceq", "seq"): kind = "lcom" if text.startswith("--") else "lstr"
        if kind not in ("ws", "com", "lcom"):
            out.append(("str" if kind in ("str", "lstr") else kind, text, line))
        line += text.count("\n"); pos = m.end()
    return out

OPENERS = {"function", "if", "do", "repeat"}
CLOSERS = {"end", "until"}

class PortFunc:
    alias = None
    def __init__(s, file, cls, name, line, body):
        s.file, s.cls, s.name, s.line, s.body = file, cls, name, line, body

def parse_lua():
    defs, enum_keys, globals_, fields = [], set(), set(), set()
    for f in PORT_FILES:
        toks = lua_tokens(open(os.path.join(ROOT, f), encoding="utf-8").read())
        n = len(toks)
        for i, (k, t, line) in enumerate(toks):
            chain, start = None, None
            if t == "function" and i + 1 < n and toks[i + 1][0] == "name":
                j = i + 1; chain = [toks[j][1]]
                while j + 2 < n and toks[j + 1][1] in (".", ":") and toks[j + 2][0] == "name":
                    chain.append(toks[j + 2][1]); j += 2
                if j + 1 < n and toks[j + 1][1] == "(": start = j + 1
                else: chain = None
            elif k == "name" and i + 3 < n and toks[i + 1][1] == "=" and toks[i + 2][1] == "function" and toks[i + 3][1] == "(":
                j = i; chain = [t]
                while j >= 2 and toks[j - 1][1] == "." and toks[j - 2][0] == "name":
                    chain.insert(0, toks[j - 2][1]); j -= 2
                start = i + 3; i0 = i + 2
            if chain is None: continue
            # body: from start's ')' to matching end
            j = start
            while toks[j][1] != ")": j += 1
            body_start, depth, j = j + 1, 1, j + 1
            while j < n and depth > 0:
                tt = toks[j][1]
                if tt in OPENERS and toks[j][0] == "name": depth += 1
                elif tt in CLOSERS and toks[j][0] == "name": depth -= 1
                j += 1
            name = chain[-1]
            cls = LUA_CLASS_ALIAS.get(chain[-2], chain[-2]) if len(chain) > 1 else None
            if cls and cls.endswith("MT") and len(cls) > 2: cls = cls[:-2]  # method tables: function ExampleAppLogMT:AddLog()
            if cls is None and re.match(r"[A-Z]\w*_[A-Z]\w*$", name) and "__" not in name:  # Class_Method globals (C++ static members)
                c, _, m = name.partition("_")
                defs.append(PortFunc(f, c, m, line, toks[body_start:j - 1]))
            pf = PortFunc(f, cls, name, line, toks[body_start:j - 1])
            bt = [x[1] for x in pf.body]
            if len(bt) >= 5 and bt[0] == "return" and bt[-3:] == ["(", "...", ")"] and all(x[0] == "name" or x[1] in (".", ":") for x in pf.body[1:-3]):
                pf.alias = " ".join(bt[1:-3]) + "(...)"; pf.body = pf.body[1:-3]  # forwarder: function(...) return ImGui.X(...) end
            defs.append(pf)
        # aliases / factories:  ImGui.DragFloat2 = DragFloatN(2)   ImFormatString = string.format   ImGui.LogTextV = ImGui.LogText
        for i, (k, t, line) in enumerate(toks):
            if k != "name" or (i and toks[i - 1][2] == line) or t == "local": continue
            j, chain = i, [t]
            while j + 2 < n and toks[j + 1][1] == "." and toks[j + 2][0] == "name":
                chain.append(toks[j + 2][1]); j += 2
            if j + 2 >= n or toks[j + 1][1] != "=" or toks[j + 2][0] != "name" or toks[j + 2][1] in ("function", "nil", "true", "false", "not"): continue
            if len(chain) == 1 and not re.match(r"(Im|STB|IMSTB|stb)", t): continue
            if len(chain) > 1 and chain[0] not in ("ImGui", "ImStd", "ImStb", "MT") and chain[-2] not in LUA_CLASS_ALIAS: continue
            rhs = [x for x in toks[j + 2:] if x[2] == toks[j + 2][2]]
            cls = LUA_CLASS_ALIAS.get(chain[-2], chain[-2]) if len(chain) > 1 else None
            pf = PortFunc(f, cls, chain[-1], line, rhs); pf.alias = " ".join(x[1] for x in rhs[:6])
            defs.append(pf)
        # enum tables / globals / fields
        depth_stack = []
        for i, (k, t, line) in enumerate(toks):
            if t == "{":
                owner = None
                if i >= 2 and toks[i - 1][1] == "=" and toks[i - 2][0] == "name": owner = toks[i - 2][1]
                depth_stack.append(owner)
            elif t == "}":
                if depth_stack: depth_stack.pop()
            elif k == "name" and i + 1 < n and toks[i + 1][1] == "=":
                prev = toks[i - 1][1] if i else ""
                if prev in ("{", ",", ";") or (prev == "." ) or (prev not in ("local", "for") and toks[i - 1][0] != "name" and prev not in ("]", ")")):
                    fields.add(t)
                if prev in ("{", ",") and depth_stack and depth_stack[-1]: enum_keys.add((depth_stack[-1], t))
                if prev == "." and i >= 2: enum_keys.add((toks[i - 2][1], t))
                if prev not in (".", "local", ",") and not depth_stack: globals_.add(t)
            elif k == "str" and i >= 1 and toks[i - 1][1] == "[" and i + 2 < n and toks[i + 1][1] == "]" and toks[i + 2][1] == "=" and depth_stack and depth_stack[-1]:
                enum_keys.add((depth_stack[-1], toks[i][1].strip("\"'")))
    return defs, enum_keys, globals_, fields

# ---------------------------------------------------------------------------------------------------------------------
# Normalization + similarity
# ---------------------------------------------------------------------------------------------------------------------
CPP_DROP = {"const", "static", "float", "int", "unsigned", "signed", "bool", "char", "void", "auto", "double", "size_t", "short", "long",
            "ImU8", "ImU16", "ImU32", "ImU64", "ImS8", "ImS16", "ImS32", "ImS64", "ImWchar", "ImGuiID", "struct", "inline", "IMGUI_API",
            "constexpr", "template", "typename", "IM_UNUSED", "this", ";", "{", "}", "(", ")", "&", "*", "ImGuiContext", "ImGuiWindow", "ImGuiStyle",
            "ImGuiIO", "ImDrawList", "ImFont", "ImRect", "ImVec2", "ImVec4", "case", "break", "default", ":", "[", "]"}
LUA_DROP = {"local", "then", "do", "end", "self", "(", ")", ";", "{", "}", "&", "*", "[", "]", ":", "bit32", "math", "string", "table"}
LUA_MAP = {"~=": "!=", "not": "!", "and": "&&", "or": "||", "nil": "NULL", "elseif": "else if", "band": "&", "bor": "|", "bxor": "^",
           "bnot": "~", "lshift": "<<", "rshift": ">>", "btest": "&", "ImMax": "ImMax", "ImMin": "ImMin"}
CPP_MAP = {"->": ".", "::": ".", "nullptr": "NULL", "++": "+=", "--": "-=", "IM_COUNTOF": "#", "IM_ARRAYSIZE": "#", "true": "true", "false": "false"}

def norm_num(t):
    try:
        if t.lower().startswith("0x"): return str(int(t.rstrip("uUlL").replace("'", ""), 16))
        return repr(float(t.rstrip("fFuUlL").replace("'", "")))
    except ValueError: return t

def split_enum(t):
    m = re.match(r"(Im[A-Za-z]+)_(\w+)$", t)
    return [m.group(1), ".", m.group(2)] if m and not t.endswith("_") else [t]

def norm_cpp(body):
    out = []
    for k, t, _, _ in body:
        if k == "num": out.append(norm_num(t)); continue
        if k == "str": out.append("S"); continue
        t = CPP_MAP.get(t, t)
        if t in CPP_DROP: continue
        out.extend(split_enum(t) if k == "name" else [t])
    o2 = []
    for i, t in enumerate(out):  # drop the implicit ImGui:: qualifier (C++ calls inside the namespace omit it)
        if t == "ImGui" and i + 1 < len(out) and out[i + 1] == ".": continue
        if t == "." and o2 and o2[-1] in (".",): continue
        o2.append(t)
    return [t for i, t in enumerate(o2) if not (t == "." and (i == 0 or o2[i - 1] in ("(", ",", "=", "return")))]

def norm_lua(body):
    out = []
    for k, t, _ in body:
        if k == "num": out.append(norm_num(t)); continue
        if k == "str": out.append("S"); continue
        if t in LUA_DROP: continue
        t = LUA_MAP.get(t, t)
        out.extend(t.split(" ") if " " in t else [t])
    o2 = []
    for i, t in enumerate(out):
        if t == "ImGui" and i + 1 < len(out) and out[i + 1] == ".": continue
        if t == "." and (not o2 or o2[-1] in ("&", "|", "^", "~", "<<", ">>", "=", ",", "return", "if", "while", "!")): continue
        o2.append(t)
    return o2

def similarity(a, b):
    if not a and not b: return 1.0
    return SequenceMatcher(None, a, b, autojunk=False).ratio()

def is_stub(port_norm, up_norm):
    real = [t for t in port_norm if t not in ("return", "NULL", "false", "true", "0.0", "S", "IM_ASSERT", "!", ",", "=", "0")]
    return len(up_norm) > 12 and (len(real) < 3 or not any(re.match(r"[A-Za-z_]\w*$", t) for t in real))

# ---------------------------------------------------------------------------------------------------------------------
def main():
    defs, enum_keys, lua_globals, lua_fields = parse_lua()
    by_name = {}
    for d in sorted(defs, key=lambda d: d.alias is not None): by_name.setdefault(d.name, []).append(d)
    port_classes = {d.cls for d in defs if d.cls}
    port_class_files = {}
    for d in defs:
        if d.cls: port_class_files.setdefault(d.cls, set()).add(d.file)

    def find(u):
        m = re.match(r"I?M?STB_TEXTEDIT_(\w+?)(_IMPL)?$", u.name)
        if m:  # STB_TEXTEDIT_INSERTCHARS / IMSTB_TEXTEDIT_GETNEXTCHARINDEX_IMPL -> ImStb.TEXTEDIT_*
            c = [d for d in by_name.get("TEXTEDIT_" + m.group(1), []) if d.cls == "ImStb"]
            return c[0] if c else None
        cands = by_name.get(u.name, [])
        if u.cls and u.cls not in ("ImGui",):
            exact = [d for d in cands if d.cls == u.cls]
            if exact: return exact[0]
            if u.name == u.cls:  # constructor: function ImGuiStyle() / MT.X.new
                c = [d for d in cands if d.cls is None] or [d for d in by_name.get("new", []) if d.cls == u.cls]
                return c[0] if c else None
            if u.cls in port_classes:  # only a classless helper in the class's own file (local function _grow_capacity)
                loose = [d for d in cands if d.cls is None and d.file in port_class_files[u.cls]] if len(cands) == 1 else []
                return loose[0] if loose else None
            loose = [d for d in cands if d.cls in (None, "ImGui")] if len(cands) == 1 else []
            return loose[0] if loose else None
        pref = [d for d in cands if d.cls == "ImGui"] + [d for d in cands if d.cls is None] + [d for d in cands if d.cls in ("ImStd", "ImStb")]
        return pref[0] if pref else None

    up_names = set()
    for f in CPP_FILES:
        for u in parse_cpp(f)[0]: up_names.add(u.name)
    def expand(p, depth=0, seen=()):
        """Port body with calls to port-only helpers in the same file inlined (the port splits some big functions)."""
        out, body = [], p.body
        for i, x in enumerate(body):
            out.append(x)
            if depth < 3 and x[0] == "name" and i + 1 < len(body) and body[i + 1][1] == "(" and x[1] not in up_names and (i == 0 or body[i - 1][1] not in (".", ":")):
                h = [d for d in by_name.get(x[1], []) if d.file == p.file and not d.alias and d is not p and d.name not in seen]
                if h: out.extend(expand(h[0], depth + 1, seen + (p.name,)))
        return out

    report, summary = [], []
    all_up = {}
    enums_all, structs_all, decls_by_file = {}, {}, {}
    for f in CPP_FILES:
        funcs, enums, structs, decls = parse_cpp(f)
        merged = {}
        for u in funcs:  # merge overloads (keep the largest body for similarity)
            if u.key not in merged or len(u.body) > len(merged[u.key].body):
                if u.key in merged and merged[u.key].excl is None: u.excl = None
                merged[u.key] = u
            elif u.excl is None: merged[u.key].excl = None
        all_up[f] = list(merged.values())
        for k, v in enums.items(): enums_all.setdefault(k, v)
        for k, v in structs.items():
            if k in structs_all: structs_all[k][0].extend(x for x in v[0] if x[0] not in {y[0] for y in structs_all[k][0]})
            else: structs_all[k] = v
        decls_by_file[f] = decls

    port_src = "\n".join(open(os.path.join(ROOT, f), encoding="utf-8").read() for f in PORT_FILES)
    ev_ok = {ev: ev is None or re.search(ev, port_src) is not None for _, _, ev in REPLACED}
    def replaced(key):
        return next((why for pat, why, ev in REPLACED if ev_ok[ev] and fnmatchcase(key, pat)), None)

    tot = {"n": 0, "have": 0, "stub": 0, "size": 0, "size_have": 0, "simw": 0.0, "size_sim": 0, "repl": 0}
    for f in CPP_FILES:
        rows = []
        st = {"n": 0, "have": 0, "stub": 0, "size": 0, "size_have": 0, "simw": 0.0, "size_sim": 0, "repl": 0}
        for u in sorted(all_up[f], key=lambda u: u.line):
            un = norm_cpp(u.body)
            if u.excl:
                rows.append((u.section, "[-]", "", u, None, u.excl)); continue
            p = find(u)
            why = replaced(u.key) if p is None else None
            if why:
                st["repl"] += 1; rows.append((u.section, "[=]", "", u, None, why)); continue
            st["n"] += 1; st["size"] += len(un)
            if p is None:
                rows.append((u.section, "[ ]", "", u, None, "")); continue
            body = p.body
            if p.alias:  # ImGui.X = ImGui.Y / Factory(n): compare against the target's body when it is a plain reference
                tgt = [x[1] for x in p.body if x[0] == "name"]
                t = by_name.get(tgt[-1]) if tgt and all(x[1] == "." or x[0] == "name" for x in p.body) else None
                t = [d for d in (t or []) if not d.alias]
                body = t[0].body if t else None
            if body is None:  # alias of a Lua builtin / factory: ported, but no body to compare
                st["have"] += 1; st["size_have"] += len(un)
                rows.append((u.section, "[x]", "  n/a", u, p, "= " + p.alias)); continue
            pn = norm_lua(expand(p) if not p.alias else body)
            sim = similarity(un, pn)
            stub = is_stub(pn, un) and not p.alias
            st["have"] += 1; st["size_have"] += len(un); st["simw"] += sim * len(un); st["size_sim"] += len(un)
            if stub: st["stub"] += 1
            rows.append((u.section, "[~]" if stub else "[x]", "%3.0f%%" % (100 * sim), u, p, "stub" if stub else ("= " + p.alias if p.alias else "")))
        for k in tot: tot[k] += st[k]
        summary.append((f, st))
        report.append((f, rows))

    def pct(a, b): return "%5.1f%%" % (100.0 * a / b) if b else "    - "

    # enums / fields / API declarations
    enum_rows, enum_n, enum_have = [], 0, 0
    for nm, (vals, line, sec) in sorted(enums_all.items(), key=lambda x: x[0]):
        base = re.sub(r"(Private)?_$", "", nm)
        missing, have, counted = [], 0, 0
        for v, vline, excl in vals:
            if excl or v.endswith("_COUNT") and False: continue
            pre, _, key = v.partition("_")
            ok = v in lua_globals or (pre, key) in enum_keys or (base, key) in enum_keys or (nm, v) in enum_keys or (base, v) in enum_keys
            if not ok and not key: ok = v in lua_globals
            enum_n += 1; counted += 1
            if ok: have += 1; enum_have += 1
            else: missing.append(v)
        enum_rows.append((nm, have, counted, missing))

    field_rows, field_n, field_have, field_repl = [], 0, 0, 0
    for nm, (fl, line, sec) in sorted(structs_all.items()):
        fl = [x for x in fl if not x[2]]
        repl = [x[0] for x in fl if x[0] not in lua_fields and replaced("%s::%s" % (nm, x[0]))]
        fl = [x for x in fl if x[0] not in repl]
        if not fl and not repl: continue
        missing = [x[0] for x in fl if x[0] not in lua_fields]
        field_n += len(fl); field_have += len(fl) - len(missing); field_repl += len(repl)
        field_rows.append((nm, len(fl) - len(missing), len(fl), missing, repl))

    api_rows, api_repl = [], 0
    port_names = set(by_name)
    for f, label in (("imgui.h", "Public API (imgui.h, namespace ImGui)"), ("imgui_internal.h", "Internal API (imgui_internal.h, namespace ImGui)")):
        d = {k: v for k, v in decls_by_file[f].items() if not v[1]}
        r = [k for k in d if k not in port_names and replaced("ImGui::" + k)]
        api_repl += len(r)
        for k in r: del d[k]
        have = [k for k in d if k in port_names]
        api_rows.append((label, len(have), len(d), sorted((k for k in d if k not in port_names), key=lambda k: d[k][0]), d))

    # ------------------------------------------------------------------ summary (stdout + file)
    head = []
    head.append("%-22s %9s %9s %9s %11s %9s %9s" % ("upstream file", "funcs", "ported", "by size", "similarity", "stubs", "replaced"))
    for f, s in summary:
        head.append("%-22s %9d %9s %9s %11s %9d %9d" % (f, s["n"], pct(s["have"], s["n"]), pct(s["size_have"], s["size"]),
                    pct(s["simw"], s["size_sim"]), s["stub"], s["repl"]))
    head.append("%-22s %9d %9s %9s %11s %9d %9d" % ("TOTAL", tot["n"], pct(tot["have"], tot["n"]), pct(tot["size_have"], tot["size"]),
                pct(tot["simw"], tot["size_sim"]), tot["stub"], tot["repl"]))
    head.append("")
    head.append("upstream code reproduced (similarity x ported size / all upstream size): %s" % pct(tot["simw"] / max(1, tot["size_sim"]) * tot["size_have"], tot["size"]))
    for label, h, n, _, _ in api_rows: head.append("%-52s %4d / %4d  %s" % (label, h, n, pct(h, n)))
    head.append("%-52s %4d / %4d  %s" % ("Enum values (imgui.h + imgui_internal.h)", enum_have, enum_n, pct(enum_have, enum_n)))
    head.append("%-52s %4d / %4d  %s" % ("Struct fields (imgui.h + imgui_internal.h)", field_have, field_n, pct(field_have, field_n)))
    head.append("%d intentionally replaced by Lua equivalents [=] (%d functions, %d API declarations, %d struct fields), not counted above"
                % (tot["repl"] + api_repl + field_repl, tot["repl"], api_repl, field_repl))
    print("\n".join(head))

    L = []
    L.append("PORT STATUS: imgui-luau vs upstream Dear ImGui (docking, %s)" % re.search(r'IMGUI_VERSION\s+"([^"]+)"', open(os.path.join(UP, "imgui.h")).read()).group(1))
    L.append("Generated by tools/compare_upstream.py - do not edit. Upstream sources: tools/test/upstream/.")
    L.append("")
    L.append("Columns:  funcs      = upstream function definitions (overloads merged), excluding [-] rows")
    L.append("          ported     = share that has a port definition with the same name")
    L.append("          by size    = same, weighted by upstream body size (tokens)")
    L.append("          similarity = normalized token similarity of the ported bodies (difflib ratio), weighted by size")
    L.append("          stubs      = ported but (nearly) empty in the port")
    L.append("          replaced   = [=] rows: intentionally replaced by a Lua mechanism (REPLACED table), excluded from funcs")
    L.append("Name-based matching: a renamed port function shows as [ ], a same-named one counts even if it differs. Treat as estimates.")
    L.append("Port-only helpers called from a ported function (same file) are inlined before comparing, since the port splits some big functions.")
    L.append("Known low scores that are not missing code: data-driven port code (e.g. DemoWindowTables' section table), the older 1.92")
    L.append("polyline stroker (AddPolyline), Lua-native replacements (ImGuiStorage, ImStr*, ImFormatString -> string.format).")
    L.append("")
    L += head
    L.append("")
    L.append("Legend: [x] ported (sim %)   [~] stub   [ ] not ported   [=] replaced by Lua equivalent (reason)   [-] excluded (c++-only / obsolete / os-specific / #if 0 / test-engine)")
    for f, rows in report:
        L.append("")
        L.append("=" * 100)
        L.append("%s" % f)
        L.append("=" * 100)
        cur = None
        for sec, mark, sim, u, p, note in rows:
            if sec != cur:
                cur = sec; L.append(""); L.append("  -- %s" % (sec or "(top)"))
            where = "%s:%d" % (p.file, p.line) if p else ""
            L.append("  %s %5s  %-58s %-32s %s" % (mark, sim, u.key, where, note))
    L.append("")
    L.append("=" * 100)
    L.append("API declarations not ported (by upstream line; [=] replacements excluded)")
    L.append("=" * 100)
    for label, h, n, missing, d in api_rows:
        L.append(""); L.append("  %s: %d / %d" % (label, h, n))
        cur = None
        for k in missing:
            if d[k][2] != cur: cur = d[k][2]; L.append("    -- %s" % (cur or "(top)"))
            L.append("    [ ] ImGui::%s" % k)
    L.append("")
    L.append("=" * 100)
    L.append("Enums (values ported / total; missing listed)")
    L.append("=" * 100)
    for nm, h, n, missing in enum_rows:
        if not n: continue
        L.append("  %-40s %4d / %4d%s" % (nm, h, n, ("   missing: " + ", ".join(missing)) if missing else ""))
    L.append("")
    L.append("=" * 100)
    L.append("Struct fields (name found in the port / total; missing listed; [=] replaced by Lua equivalent, excluded from total). Field names are matched globally, so common names may over-count.")
    L.append("=" * 100)
    for nm, h, n, missing, repl in field_rows:
        L.append("  %-40s %4d / %4d%s%s" % (nm, h, n, ("   missing: " + ", ".join(missing)) if missing else "",
                                           ("   [=] " + ", ".join("%s (%s)" % (x, replaced("%s::%s" % (nm, x))) for x in repl)) if repl else ""))
    out = os.path.join(ROOT, "docs", "PORT_STATUS.txt")
    open(out, "w").write("\n".join(L) + "\n")
    print("\nwrote docs/PORT_STATUS.txt")

if __name__ == "__main__":
    main()
