-- [Roblox] `imgui` is a ModuleScript (this file) whose descendants are the other files as ModuleScripts
-- (what Rojo produces from this folder). ModuleScripts don't share globals, so every imgui file runs inside
-- one shared environment table (_G.__IMGUI_ENV). require() of this module returns that environment.
if game and script then
    local env = setmetatable({}, { __index = getfenv(1) })
    env.IMGUI_ROOT = script
    _G.__IMGUI_ENV = env
    require(script:FindFirstChild("imgui"))
    require(script:FindFirstChild("imgui_impl_roblox", true))
    require(script:FindFirstChild("imgui_demo"))
    return env
end

-- LOVE / LuaJIT
require("imgui.imgui")
require("imgui.backend.imgui_impl_love")
require("imgui.imgui_demo")
