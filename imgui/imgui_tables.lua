if _G.__IMGUI_ENV then setfenv(1, _G.__IMGUI_ENV) end -- [Roblox] shared env, see init.lua
--- ImGui Sincerely WIP
-- (Tables and Columns Code)

--- @type ImGuiContext?
local GImGui

-- Sets local `GImGui` in this file(imgui_tables.lua).
-- This is currently only used in main code `ImGui.SetCurrentContext()`
--- @param ctx ImGuiContext?
function ImGui._SetCurrentContext_Tables(ctx)
    GImGui = ctx
end

--- @param str_id        string
--- @param columns_count int
--- @param flags?        ImGuiTableFlags
--- @param outer_size?   ImVec2
--- @param inner_width?  float
function ImGui.BeginTable(str_id, columns_count, flags, outer_size, inner_width)
    if flags       == nil then flags       = 0                end
    if outer_size  == nil then outer_size  = ImVec2(0.0, 0.0) end
    if inner_width == nil then inner_width = 0.0              end

    -- TODO:
    return true
end

function ImGui.EndTable()
    -- TODO:
end

function ImGui.TableNextColumn()
    -- TODO:
end

function ImGui.TablePushBackgroundChannel()
    -- TODO:
end

function ImGui.TablePopBackgroundChannel()
    -- TODO:
end

return true -- [Roblox] ModuleScripts must return exactly one value
