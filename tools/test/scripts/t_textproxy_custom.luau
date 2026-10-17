-- Text proxy for a custom widget (no ActiveId): it sets PlatformImeData.WantTextInput/SelectedText while its window is focused.
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
local UIS = game:GetService("UserInputService")
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init(); G.ImGui_ImplRoblox.SetTextProxy(true)
local io = ImGui.GetIO()
local got, proxy, f = "", nil, 0
game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    proxy = proxy or game:GetService("Players").LocalPlayer.PlayerGui.ImGui.TextProxy
    if f == 3 then io:AddMousePosEvent(60, 45); io:AddMouseButtonEvent(0, true) end
    if f == 4 then io:AddMouseButtonEvent(0, false) end
    if f == 8 then assert(UIS:GetFocusedTextBox() == proxy, "proxy focused"); proxy.Text = "x" end
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(300, 100))
    ImGui.Begin("Editor")
    if ImGui.IsWindowFocused() then
        local ime = ImGui.GetCurrentContext().PlatformImeData
        ime.WantTextInput = true; ime.SelectedText = "abc"
        local q = io.InputQueueCharacters
        for i = 1, q.Size do got ..= utf8.char(q.Data[i]) end
    end
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())
    if f == 12 then
        assert(got == "x", "widget got: " .. got)
        assert(proxy.Text == "abc", "mirror: " .. proxy.Text)
        print("CUSTOM PROXY OK")
    end
end)
