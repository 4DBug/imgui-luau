-- Text proxy: typing/paste arrive through the hidden TextBox, and its text mirrors the InputText selection (for copy).
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local UIS = game:GetService("UserInputService")
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local buf = ImGui.NewTextBuffer("", 64)
local proxy
local f = 0
game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    proxy = proxy or game:GetService("Players").LocalPlayer.PlayerGui.ImGui.TextProxy
    if f == 3 then io:AddMousePosEvent(60, 45); io:AddMouseButtonEvent(0, true) end
    if f == 4 then io:AddMouseButtonEvent(0, false) end
    if f == 8 then assert(UIS:GetFocusedTextBox() == proxy, "proxy focused"); proxy.Text = "abc" end            -- typed
    if f == 10 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); proxy.Text = "hello world" end -- pasted with Ctrl held
    if f == 11 then io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end                                                             -- pasted
    if f == 13 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.A, true) end             -- select all
    if f == 14 then io:AddKeyEvent(G.ImGuiKey.A, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(300, 100))
    ImGui.Begin("T"); ImGui.InputText("##t", buf, 64); ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 12 then local st = ImGui.GetCurrentContext().InputTextState  -- (buf itself is written on validation/deactivation)
        local got = G.ImGui._ByteArrayToString(st.TextA.Data, 1, st.TextLen + 1)
        assert(got == "abchello world", "text: " .. got) end
    if f == 15 then proxy:_loseFocus() end
    -- keys while the proxy reports focus but receives nothing (Roblox silently not delivering): must still type
    if f == 20 then
        io:AddMousePosEvent(60, 45); io:AddMouseButtonEvent(0, true)
    end
    if f == 21 then io:AddMouseButtonEvent(0, false) end
    if f == 24 then
        assert(UIS:GetFocusedTextBox() == proxy, "proxy focused again")
        local k = { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Z, Position = { X = 0, Y = 0, Z = 0 } }
        UIS.InputBegan:Fire(k, true); UIS.InputEnded:Fire(k, true)
    end -- click inside imgui (mouse is over the field): edit must survive
    if f == 16 then
        assert(ImGui.GetCurrentContext().ActiveId ~= 0, "edit ended by a click inside imgui")
        assert(UIS:GetFocusedTextBox() == proxy, "proxy not recaptured")
        assert(proxy.Text == "abchello world", "selection mirror: " .. tostring(proxy.Text))
        io:AddMousePosEvent(900, 900) -- move off imgui, then the user clicks into the game
    end
    if f == 17 then proxy:_loseFocus() end
    if f == 19 then
        assert(ImGui.GetCurrentContext().ActiveId == 0, "field still active after focus lost")
        assert(UIS:GetFocusedTextBox() == nil, "proxy recaptured")
        assert(ImGui.TextBufferToString(buf) == "abchello world", "buf: " .. ImGui.TextBufferToString(buf))
    end
    -- click inside the field with a selection (Roblox drops focus on press, we recapture on release): selection must survive
    if f == 28 then io:AddKeyEvent(G.ImGuiMod_Ctrl, true); io:AddKeyEvent(G.ImGuiKey.A, true) end
    if f == 29 then io:AddKeyEvent(G.ImGuiKey.A, false); io:AddKeyEvent(G.ImGuiMod_Ctrl, false) end
    if f == 31 then proxy:_loseFocus() end
    if f == 34 then
        local st = ImGui.GetCurrentContext().InputTextState
        assert(st:HasSelection(), "selection lost after refocus")
        assert(#proxy.Text > 5 and proxy.Text == G.ImGui._ByteArrayToString(st.TextA.Data, 1, st.TextLen + 1), "mirror after refocus: " .. proxy.Text)
        print("REFOCUS OK")
        proxy.Text = proxy.Text:sub(1, -2) -- Roblox Backspace without a real TextBox selection: removes 1 char
    end
    if f == 37 then
        local st = ImGui.GetCurrentContext().InputTextState
        assert(st.TextLen == 0, "backspace should delete imgui's whole selection, len " .. st.TextLen)
        print("BACKSPACE OK")
    end
    if f == 27 then
        local st = ImGui.GetCurrentContext().InputTextState
        local got = G.ImGui._ByteArrayToString(st.TextA.Data, 1, st.TextLen + 1)
        assert(got:find("z"), "key fallback while proxy focused: " .. got)
        print("PROXY OK")
    end
end)
