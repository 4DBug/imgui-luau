#!/usr/bin/env python3
# Typed entry module for the Roblox build: bundle.py writes build/ImGuiTyped.luau = Luau types + `require(script.Impl)`,
# where Impl is the untouched build/ImGui.luau (the bundle itself is too large for Luau's type inference to finish,
# so the types live in this small wrapper instead). Library sources and the LÖVE build are not affected.
# Public ImGui.* signatures come from upstream imgui.h (namespace ImGui), mapped onto the port's own parameter lists.
# Anything ambiguous (overloads, char* buffers, arrays, multiple out-params, count mismatch) falls back to `any`,
# so the types never reject code that runs. Enum tables (ImGuiWindowFlags, ImGuiCol, ...) get their exact keys.
# Self-check: python3 tools/gen_types.py  (prints a few signatures)
import os, re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NUM = re.compile(r"^(int|float|double|unsigned int|unsigned short|short|size_t|ImU32|ImS32|ImU64|ImS64|ImWchar|ImGuiID|Im\w*Flags|ImGui(Col|Cond|StyleVar|Key|MouseButton|MouseCursor|Dir|DataType|SortDirection|TableBgTarget|Axis))$")
VEC = {"ImVec2": "ImVec2", "ImVec4": "ImVec4"}

def lua_type(ctype):
    t = re.sub(r"\bconst\b|&", "", ctype).strip()
    t = re.sub(r"\s+", " ", t)
    if t == "char*": return "string" if "const" in ctype else None
    if t == "bool": return "boolean"
    if NUM.match(t): return "number"
    return VEC.get(t)

def split_params(s):
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([": depth += 1
        if ch in ")]": depth -= 1
        if ch == "," and depth == 0: out.append(cur); cur = ""
        else: cur += ch
    if cur.strip(): out.append(cur)
    return [p.strip() for p in out]

def upstream_decls():
    src = open(os.path.join(ROOT, "tools", "test", "upstream", "imgui.h")).read()
    body = src[src.index("namespace ImGui\n"):src.index("} // namespace ImGui")]
    decls = {}
    for m in re.finditer(r"IMGUI_API\s+([\w\s\*&]+?)\s*\b(\w+)\((.*?)\)\s*(?:IM_FMT\w+\(\d+\))?\s*;", body):
        decls.setdefault(m.group(2), []).append((m.group(1).strip(), split_params(m.group(3)) if m.group(3).strip() not in ("", "void") else []))
    return decls

LOOSE = "(...any) -> ...any"

def signature(port_params, ret, cparams):
    if any(p == "..." for p in cparams):
        if port_params and port_params[-1] == "...": port_params = port_params[:-1]
        cparams = [p for p in cparams if p != "..."]; vararg = True
    else: vararg = False
    if len(port_params) != len(cparams): return LOOSE
    args, outs = [], []
    for name, cp in zip(port_params, cparams):
        decl, _, default = cp.partition("=")
        m = re.match(r"(.*?)\b(\w+)\s*(\[\w*\])?\s*$", decl.strip())
        if not m: return LOOSE
        ctype, array = m.group(1).strip(), m.group(3)
        if "(*" in cp: return LOOSE
        ptr = ctype.endswith("*") and not re.search(r"\bchar\s*\*$", ctype)
        if array: t = None; outs.append("array")
        elif ptr and re.search(r"\bconst\b", ctype): t = None  # input array (e.g. ColorPicker4 ref_col)
        elif ptr:
            t = lua_type(ctype[:-1])
            if t in ("boolean", "number"): outs.append(t)
            else: t = None; outs.append("other")
        else: t = lua_type(ctype)
        if name == "...": args.append("...any"); continue
        opt = "?" if (default.strip() or (ptr and t == "boolean")) else ""
        args.append("%s: %s%s" % (name, t or "any", opt if t else ""))
    if vararg: args.append("...any")
    r = re.sub(r"\bconst\b|&|IMGUI_API", "", ret).strip()
    if r == "void": rt = "...any" if outs else "()"
    elif r == "bool":
        scal = [o for o in outs if o != "array"]
        if not scal: rt = "boolean"
        elif len(scal) == 1 and scal[0] == "boolean": rt = "(boolean, boolean?)"
        elif len(scal) == 1 and scal[0] == "number": rt = "(number, boolean)"
        else: rt = "...any"
    else:
        rt = lua_type(r) or "any"
        if outs: rt = "...any"
    return "(%s) -> %s" % (", ".join(args), rt)

def port_functions(files):
    fns = {}
    for src in files.values():
        for m in re.finditer(r"^function ImGui\.(\w+)\((.*?)\)", src, re.M):
            fns[m.group(1)] = [p.strip() for p in m.group(2).split(",") if p.strip()]
    return fns

def enums(files):
    src = files.get("imgui_h.lua", "")
    out = {}
    for m in re.finditer(r"^(Im\w+) = \{\n(.*?)^\}", src, re.M | re.S):
        keys = re.findall(r"^\s+(\w+)\s*=", m.group(2), re.M)
        if keys: out[m.group(1)] = keys
    for f in files.values():  # keys added later (ImGuiKey letters in loops are covered by the indexer below)
        for name, key in re.findall(r"^\s*(Im\w+)\.(\w+)\s*=", f, re.M):
            if name in out and key not in out[name]: out[name].append(key)
    return out

def types_header(files):
    decls, fns = upstream_decls(), port_functions(files)
    lines = ["export type ImVec2 = { x: number, y: number, [any]: any }",
             "export type ImVec4 = { x: number, y: number, z: number, w: number, [any]: any }",
             "export type ImGuiAPI = {"]
    for name in sorted(fns):
        d = decls.get(name)
        sig = signature(fns[name], *d[0]) if d and len(d) == 1 else LOOSE
        lines.append("    %s: %s," % (name, sig))
    lines += ["    [string]: any,", "}"]
    for name, keys in sorted(enums(files).items()):
        lines.append("export type %s = { %s, [string]: number }" % (name, ", ".join("%s: number" % k for k in keys)))
    return lines + module_type(set(enums(files)))

def wrapper(files):
    return "\n".join(["--!strict", "-- GENERATED by tools/gen_types.py - do not edit. The library is the child ModuleScript 'Impl'.", ""]
                     + types_header(files) + ["", "return (require(script:WaitForChild(\"Impl\")) :: any) :: ImGuiModule", ""])

def module_type(enum_names):
    # the bundle is too large for Luau to infer, so its return value is cast to this explicit type
    lines = ["export type ImGuiModule = {", "    ImGui: ImGuiAPI,"]
    lines += ["    %s: (x: number?, y: number?, z: number?, w: number?) -> %s," % (n, n) for n in ("ImVec2", "ImVec4")]
    lines += ["    %s: %s," % (n, n) for n in sorted(enum_names)]
    return lines + ["    [string]: any,", "}"]

if __name__ == "__main__":
    import glob
    files = {os.path.basename(f): open(f).read() for f in glob.glob(os.path.join(ROOT, "*.lua"))}
    lines = types_header(files)
    for l in lines:
        if re.match(r"    (Begin|Checkbox|SliderFloat|SliderFloat3|Text|Button|Combo|GetCursorPos|InputText|DragFloatRange2):", l): print(l)
    loose = sum(LOOSE in l for l in lines); print("%d functions, %d loose" % (sum(l.startswith("    ") for l in lines), loose))
