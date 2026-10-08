Dear ImGui for Roblox
=====

<center><b><i>"Give someone state and they'll have a bug one day, but teach them how to represent state in two separate locations that have to be kept in sync and they'll have bugs for a lifetime."</i></b></center> <a href="https://twitter.com/rygorous/status/1507178315886444544">-ryg</a>

----

A Luau port of [Dear ImGui](https://github.com/ocornut/imgui) (docking branch, 1.93 WIP) for Roblox, rendered with EditableImages. It follows the C++ source function by function, so upstream documentation, examples and the demo apply almost directly.

| [The Pitch](#the-pitch) - [Usage](#usage) - [How it works](#how-it-works) - [Demo](#demo) - [Getting Started & Integration](#getting-started--integration) |
:----------------------------------------------------------: |
| [Differences from C++](#differences-from-c-dear-imgui) - [Performance](#performance) - [Testing](#testing) - [Not ported yet](#not-ported-yet) |
| [FAQ](#faq) - [Credits](#credits) - [License](#license) |

### The Pitch

Dear ImGui is a **bloat-free graphical user interface library**. It outputs optimized vertex buffers that you can render anytime in your application. It is fast, portable, renderer agnostic, and self-contained.

Dear ImGui is designed to **enable fast iterations** and to **empower programmers** to create **content creation tools and visualization / debug tools** (as opposed to UI for the average end-user). It favors simplicity and productivity toward this goal and lacks certain features commonly found in more high-level libraries.

This port brings that to Roblox: debug overlays, admin panels, in-game editors, profilers and dev tools, written as plain Luau code with no Instances to create, parent or clean up. It includes docking, tables, multiple fonts, the full Style Editor, the Metrics/Debugger window and the complete demo.

### Usage

**The core of Dear ImGui is a set of files with no dependencies**, bundled by `tools/bundle.py` into one ModuleScript (`build/ImGui.luau`). The Roblox backend (`backends/imgui_impl_roblox.lua`) is included in the bundle.

Dear ImGui is **immediate mode**: you call widget functions every frame, and their return values tell you what the user did. There is no widget object to keep in sync with your state.

Code:
```lua
ImGui.Text("Hello, world %d", 123)
if ImGui.Button("Save") then
    MySaveFunction()
end
ImGui.InputText("string", buf, 256)          -- buf = ImGui.NewTextBuffer("...", 256)
f = ImGui.SliderFloat("float", f, 0.0, 1.0)
```
Result:

![sample code output (dark, light)](docs/images/debug.png)
<br>_(settings: Dark style (left), Light style (right) / Font: ProggyClean, 13px)_

Code:
```lua
-- Create a window called "My First Tool", with a menu bar.
my_tool_active = ImGui.Begin("My First Tool", my_tool_active, ImGuiWindowFlags.MenuBar)
if ImGui.BeginMenuBar() then
    if ImGui.BeginMenu("File") then
        if ImGui.MenuItem("Open..", "Ctrl+O") then --[[ Do stuff ]] end
        if ImGui.MenuItem("Save", "Ctrl+S") then --[[ Do stuff ]] end
        if ImGui.MenuItem("Close", "Ctrl+W") then my_tool_active = false end
        ImGui.EndMenu()
    end
    ImGui.EndMenuBar()
end

-- Edit a color stored as 4 floats
ImGui.ColorEdit4("Color", my_color)

-- Generate samples and plot them
for n = 1, 100 do samples[n] = math.sin((n - 1) * 0.2 + ImGui.GetTime() * 1.5) end
ImGui.PlotLines("Samples", samples, nil, 100)

-- Display contents in a scrolling region
ImGui.TextColored(ImVec4(1, 1, 0, 1), "Important Stuff")
ImGui.BeginChild("Scrolling")
for n = 0, 49 do ImGui.Text("%04d: Some text", n) end
ImGui.EndChild()
ImGui.End()
```
Result:

![my_first_tool](docs/images/tool.png)

Dear ImGui allows you to **create elaborate tools** as well as very short-lived ones. On the extreme side of short-livedness: using the Edit&Continue-friendly nature of immediate mode, you can add a slider to tweak a value in one line and remove it again a minute later.

Every snippet in this README is run by [`tools/test/scripts/t_readme.luau`](tools/test/scripts/t_readme.luau), and every image was rendered by this port with [`tools/screenshots/make.py`](tools/screenshots/make.py).

### How it works

Dear ImGui builds a list of textured triangles (`ImDrawData`) every frame. The Roblox backend turns it into pixels:

- Every window gets its own **layer** (a Frame) made of 128×128 **EditableImage tiles**. Moving a window only moves its Frame: nothing is redrawn.
- Scrolled window content sits in a `ClipsDescendants` frame positioned at the scroll offset, so scrolling moves already drawn pixels and only rows entering view are drawn.
- Tiles are hashed; only tiles whose content changed are rasterized (in Luau, with `@native`) and uploaded, and only their dirty region. A static UI costs almost nothing to render.
- While the mouse is over Dear ImGui (`io.WantCaptureMouse`), the tiles are `Active`, so clicks and the mouse wheel don't reach the game (camera zoom etc.).

### Demo

Calling `ImGui.ShowDemoWindow()` creates a demo window that showcases a variety of features and examples. The code is in [imgui_demo.lua](imgui_demo.lua), like upstream's `imgui_demo.cpp`. **It's strongly recommended to keep it at hand as a reference**: you can find the code for any widget you see by searching for its label.

![demo](docs/images/demo.png)

Tables, with sorting, resizing, reordering, borders and row backgrounds:

![tables](docs/images/tables.png)

Docking (`io.ConfigFlags |= ImGuiConfigFlags.DockingEnable`):

![docking](docs/images/docking.png)

Plotting:

![plot](docs/images/plot.gif)

Custom drawing with `ImDrawList`:

```lua
local draw_list = ImGui.GetWindowDrawList()
local p = ImGui.GetCursorScreenPos()
draw_list:AddRectFilled(p, p + ImVec2(100, 100), IM_COL32(255, 120, 60, 255), 12.0)
draw_list:AddCircleFilled(p + ImVec2(170, 50), 45, IM_COL32(80, 160, 255, 255))
draw_list:AddLine(p + ImVec2(0, 120), p + ImVec2(220, 120), IM_COL32(255, 255, 0, 255), 2.0)
ImGui.Dummy(ImVec2(220, 130)) -- reserve the space so the window sizes/scrolls correctly
```

![drawlist](docs/images/drawlist.png)

The Style Editor (`ImGui.ShowStyleEditor()`) and the Metrics/Debugger (`ImGui.ShowMetricsWindow()`):

![style editor](docs/images/style.png) ![metrics](docs/images/metrics.png)

### Getting Started & Integration

1. Build the module: `python3 tools/bundle.py` writes `build/ImGui.luau` (`--no-demo` leaves the demo out).
2. Sync with [Rojo](https://rojo.space): [`default.project.json`](default.project.json) puts the module in `ReplicatedStorage.ImGui` and the example LocalScript in `StarterPlayerScripts`.
3. A minimal LocalScript (full version: [examples/example_roblox/main.client.luau](examples/example_roblox/main.client.luau)):

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(ReplicatedStorage:WaitForChild("ImGui"))
local ImGui, ImGui_ImplRoblox = G.ImGui, G.ImGui_ImplRoblox

ImGui.CreateContext()
local io = ImGui.GetIO()
io.ConfigFlags = bit32.bor(io.ConfigFlags, G.ImGuiConfigFlags.NavEnableKeyboard, G.ImGuiConfigFlags.DockingEnable)
ImGui_ImplRoblox.Init()            -- Init(parent, render_scale): parent defaults to PlayerGui

RunService.Stepped:Connect(function()
    ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()

    ImGui.ShowDemoWindow()
    -- ... your windows ...

    ImGui.Render()
    ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
end)
```

Backend options:

| Call | Effect |
| --- | --- |
| `ImGui_ImplRoblox.Init(parent, render_scale)` | `render_scale` = your OS display scale renders at physical-pixel resolution (crisper, same size as desktop imgui). |
| `ImGui_ImplRoblox.SetRenderScale(scale)` | Change it at runtime. |
| `ImGui_ImplRoblox.SetRenderRate(hz)` | Max tile redraws per second (default 60, `0` = every frame). Your code still runs every frame. |
| `ImGui_ImplRoblox.SetBusyRenderRate(hz)` | Optional lower redraw rate while scrolling, resizing or moving windows (default off). |
| `ImGui_ImplRoblox.SetProfiling(true)` | MicroProfiler (Ctrl+F6) labels for every backend stage. |
| `ImGui_ImplRoblox.AddFile(path, bytes)` | Register a file (e.g. a `.ttf`) so `io.Fonts:AddFontFromFileTTF(path, size)` can load it. |

Fonts: ProggyClean (default), ProggyTiny, ProggyForever, Cousine, DroidSans, Karla and Roboto are embedded from [fonts/](fonts/):

```lua
io.Fonts:AddFontDefault()
io.Fonts:AddFontFromFileTTF("fonts/Roboto-Medium.ttf", 16.0)
```

### Other backends: LÖVE

The same sources also build for [LÖVE](https://love2d.org) (LuaJIT), with a GPU renderer in [backends/imgui_impl_love.lua](backends/imgui_impl_love.lua):

```
python3 tools/bundle.py --target love      # -> build/imgui_love.lua (LÖVE backend + compat/luajit.lua shims)
love examples/example_love
```

Roblox stays the primary target: the Roblox build is untouched by this (no shims, `@native` kept); the LÖVE build strips `@native` and adds small `bit32`/`buffer`/`utf8`/`table` shims ([compat/luajit.lua](compat/luajit.lua)). `tools/test/love/run.sh` checks that LuaJIT produces exactly the same draw data as Luau.

[examples/example_shared/app.lua](examples/example_shared/app.lua) is one UI that runs unchanged on both: `roblox.client.luau` (Rojo: `examples/example_shared/default.project.json`) and `main.lua` (`love examples/example_shared`) are the only platform code. Write shared UI code in plain Lua 5.1 syntax (no `+=`, `//`, `continue`).

### Differences from C++ Dear ImGui

The API is the same function-for-function; these are the Luau-specific conventions:

| C++ | Luau |
| --- | --- |
| `bool* p_open`, `float* v`, `int* v` | Passed by value, the new value is returned. |
| `bool Checkbox(label, &v)` | `pressed, v = ImGui.Checkbox(label, v)` |
| `bool SliderFloat(label, &v, ...)` | `v, changed = ImGui.SliderFloat(label, v, ...)` (same for Drag/Input/Slider scalars) |
| `bool Combo(label, &idx, items)` | `idx, changed = ImGui.Combo(label, idx, { "a", "b" })`, **0-based** index |
| `bool Begin(name, &open)` | `open, visible = ImGui.Begin(name, open)` |
| `float v[3]`, `ImVec4 col` | Arrays / `ImVec4` are edited in place (`DragFloat3`, `ColorEdit4`). |
| `char buf[256]` | `buf = ImGui.NewTextBuffer("text", 256)`, edited in place; `ImGui.TextBufferToString(buf)` |
| `ImGuiWindowFlags_MenuBar` | `ImGuiWindowFlags.MenuBar` (combine with `bit32.bor`) |
| `ImVec2 a + b` | Works (`ImVec2` has arithmetic metamethods); fields are `.x`, `.y` |
| `draw_list->AddRect(a, b, col, rounding, flags, thickness)` | `draw_list:AddRect(a, b, col, rounding, thickness, flags)` |
| `ImDrawList::VtxBuffer` (`ImDrawVert[]`) | One flat `buffer` (`VtxBuffer.Buf`, 36 bytes per vertex); read with `ImDrawVtx_Pos/ImDrawVtx_Col`. |

All exported names (`ImGui`, `ImVec2`, `ImVec4`, `IM_COL32`, every `ImGui*Flags` enum, …) are fields of the table returned by `require`.

### Performance

Measured headless (Luau CLI, Studio-like native code generation), demo window open:

| Scenario | Frame time |
| --- | --- |
| Demo idle, Widgets > Basic open | ~1.3 ms |
| Scrolling the same | ~1.9 ms |
| Dragging a window | ~0.4 ms, no tile uploads |
| Whole demo open (every section) | ~22 ms |

Most of the remaining cost is widget logic (your UI code and Dear ImGui's per-widget work), which runs every frame by design. Use `ImGuiListClipper` for long lists.

### Testing

`tools/test/run.py` runs any LocalScript headless against a mocked Roblox (`tools/test/roblox_mock.luau`):

```
python3 tools/bundle.py
python3 tools/test/run.py --main tools/test/scripts/t_tables.luau --frames 120 --quiet --roblox
```

- `t_drawhash` / `t_colors_hash`: checksums of all draw data; internal rewrites must keep them identical.
- `t_composite`: composites the backend's tiles like Roblox does, to compare pixels between versions.
- `t_click_fuzz`, `t_apps`, `t_dock*`, `t_tables`, …: behaviour tests. `--profile` + `tools/test/prof.py` for profiling.

See [docs/PORTING.md](docs/PORTING.md) for the porting rules.

### Not ported yet

Multi-select / box-select, typing-select, the Assets Browser example, the Item Picker and a few smaller items. The full list is in [docs/TODO.txt](docs/TODO.txt).

### FAQ

**Does it work on mobile / console?** Rendering does. The backend currently handles mouse and keyboard input only; touch and gamepad are not wired up yet.

**Does my UI code run when nothing changes?** Yes, every frame, like Dear ImGui. Only rendering is skipped for unchanged content.

**Can I use it for player-facing UI?** You can, but like upstream it is designed for tools: programmer-oriented, dense, and not themed for end users.

**Where is the documentation?** Upstream's docs apply: the [wiki](https://github.com/ocornut/imgui/wiki), the [FAQ](https://github.com/ocornut/imgui/blob/master/docs/FAQ.md) and the comments in `imgui.h`. The demo is the best reference.

### Credits

Dear ImGui is developed by [Omar Cornut](https://www.miracleworld.net) and [every direct or indirect contributor](https://github.com/ocornut/imgui/graphs/contributors). This repository is an unofficial port and is not affiliated with the Dear ImGui project.

This port started from [GrayWolf64/imgui-lua](https://github.com/GrayWolf64/imgui-lua), a Lua port of Dear ImGui, and was extended from there to the docking branch and Roblox.

Embeds [stb_truetype, stb_textedit, stb_rectpack](https://github.com/nothings/stb) by Sean Barrett (public domain / MIT), ported to Luau.

Fonts: ProggyClean, ProggyTiny, ProggyForever by Tristan Grimmer; Cousine, DroidSans, Karla, Roboto under their respective licenses (Apache 2.0 / SIL OFL), as distributed in upstream's `misc/fonts/`.

### License

Dear ImGui is licensed under the MIT License, see [LICENSE.txt](https://github.com/ocornut/imgui/blob/master/LICENSE.txt) for more information. This port is distributed under the same license.
