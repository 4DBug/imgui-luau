-- Runs examples/example_love and examples/example_shared main.lua headless under LuaJIT (mock love) for some frames.
for _, ex in ipairs({ "examples/example_love", "examples/example_shared" }) do
    dofile("tools/test/love/mock_love.lua")
    love.filesystem.getSource = function() return ex end
    love.filesystem.load = function(p) return assert(loadfile(ex .. "/" .. p)) end
    love.graphics.clear = function() end
    dofile(ex .. "/main.lua")
    love.load()
    for i = 1, 30 do
        love.timer.step(1 / 60)
        love.mousemoved(100 + i, 100); love.update(1 / 60); love.draw()
    end
    love.keypressed("a"); love.textinput("a"); love.keyreleased("a"); love.update(1 / 60); love.draw()
    print(ex, "OK", MOCK_DRAWS)
end
