# Porting rules (Dear ImGui docking branch -> this Lua/Luau port)

Upstream reference: `tools/test/upstream/*.cpp|h` (ocornut/imgui `docking` branch, 1.93 WIP). Port semantics 1:1 from
there, but keep this port's existing data structures and conventions. Read the surrounding existing Lua code first.

## Runtime
- Target is **Luau (Roblox)** only. All files are concatenated into one ModuleScript by `tools/bundle.py`; every
  file shares one global namespace. Globals defined by one file are visible to the others at call time.
- Each `imgui/*.lua` file is a function body in the bundle. New files must be loaded with `IM_INCLUDE"file.lua"`
  from an existing file (files named `imgui_demo*.lua` are loaded automatically, after `imgui.lua`).
- No `goto`, no `::labels::`, no `setfenv/getfenv`, no LuaJIT `bit`/`ffi`. Use `bit32`. For `continue` use
  `repeat ... until true` with `break`, and an explicit flag when the loop itself must break out of the wrapper.
- Luau has a limit of 200 locals per function and 255 upvalues; split huge functions (like demo sections) into
  several local/global functions.

## Conventions (follow what the port already does)
- `ImVector`: 1-based `.Data`, `.Size`, methods `push_back/pop_back/resize/back/iter/erase/...` (imgui_h.lua).
  Indices that C++ stores as 0-based *values* (e.g. column index, tab order) stay 0-based unless the surrounding
  port code already shifted them; document `-- 0-based` / `-- 1-based` next to anything ambiguous.
- `ImVec2(x, y)` stores `[1],[2]` with `.x/.y` aliases (metatable). Arithmetic operators exist. Prefer
  `ImVec2_Copy(dst, src)` / `ImVec2_CopyV(dst, x, y)` when C++ assigns into an existing struct field.
  `ImVec4`, `ImRect` (`.Min/.Max`) likewise.
- Structs: constructor function `ImGuiFoo()` returning a table, methods on `MT.ImGuiFoo` with
  `MT.ImGuiFoo.__index = MT.ImGuiFoo`. `local MT = ImGui.GetMetatables()`.
- Flags/enums: tables like `ImGuiTableFlags.Resizable`; combine with `bit32.bor`, test with `bit32.band(...) ~= 0`.
- Context: `local g = GImGui` (each file has its own local `GImGui` kept in sync; follow how the file you are in
  does it). New fields on `ImGuiContext`/`ImGuiWindow`: add them to the constructor in imgui_internal.lua.
- Strings: Lua strings + 1-based byte positions; `text_end` is exclusive. Editable text buffers are `char[]`
  (byte tables), like `ImGui.InputText(label, buf, buf_size)`.
- **Output parameters** (C++ `bool* p_open`, `float* v`, `int* current_item`...) become return values:
  - bool-like widgets: `return pressed, new_v`  (Checkbox, RadioButton, Selectable, MenuItem, CheckboxFlags)
  - scalar widgets: `return new_v, changed`  (Slider*/Drag*/Input* scalar, SliderAngle, Combo -> `new_idx, changed`)
  - multi-component (`float v[3]`, ImVec4 colors, `char[]` buffers): table mutated in place, return `changed`
  - `Begin(name, p_open)` style: `return open, visible` / follow existing `ImGui.Begin`.
  When an existing similar function already exists, copy its convention exactly.
- `static` locals in C++ become file-level upvalue tables / fields (demo uses a `static` table per section).
- `IM_ASSERT(cond, msg)` exists. `IM_COL32(r,g,b,a)`, `ImMax/ImMin/ImClamp/ImLerp/ImFloor/ImTrunc` etc. exist.
- Keep function names identical to upstream (`ImGui.TableNextRow`, `ImGui.TabBarLayout`, ...). Internal helpers
  that are `static` in C++ become `local function` in the file.
- Roblox can't do: OS clipboard (internal only), files/URLs (VFS `ImStd.ImFileLoadToMemory` only), multi-viewports,
  gamepad. Port the code paths anyway where cheap; demo shows "(not supported on Roblox)" text instead of
  widgets that cannot work.

## Testing
- `python3 tools/test/run.py` — runs main.client.luau 400 frames with scripted random input (mouse, clicks,
  keys, typing). Errors print with `imgui/<file>.lua:<line>` mapped stack traces.
- `--open` forces every CollapsingHeader/TreeNode open (exercises the whole demo). `--big` makes the demo
  window 900x1000. `--png out.png` writes a screenshot (Read the PNG to look at it). `--check` asserts the
  incremental renderer is pixel identical to a full redraw. `--main file.luau` runs your own test LocalScript
  (copy main.client.luau as a template: `local G = require(ReplicatedStorage:WaitForChild("ImGui"))`, all
  library globals are fields of `G`).
- `python3 tools/test/missing.py [tables|widgets|imgui.cpp]` lists upstream functions not yet ported.
- Several people edit the repo concurrently. Keep every file syntactically valid after each edit. If a run fails
  because of an error in a file you don't own, wait a minute and retry instead of editing it.
