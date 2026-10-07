function love.conf(t)
    t.console = true
    t.window.resizable = true
    t.window.msaa = 4
    t.window.width = 1920
    t.window.height = 960

    if love._version_major > 11 then
        t.window.depth = true
    else
        t.window.depth = 24
    end

   	t.window.vsync = true
	t.highdpi = true
end
