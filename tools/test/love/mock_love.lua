-- Minimal headless `love` for running build/imgui_love.lua under plain LuaJIT (tools/test/love/run.sh).
local ffi = require("ffi")
local W, H = 1920, 1080
local t = 0
local function obj(extra) local o = { release = function() end }; for k, v in pairs(extra or {}) do o[k] = v end; return o end
local function bytedata(n)
    local mem = ffi.new("uint8_t[?]", n)
    return obj({ getFFIPointer = function() return mem end, getSize = function() return n end })
end
love = {
    timer = { getTime = function() return t end, step = function(dt) t = t + dt end },
    graphics = {
        getDimensions = function() return W, H end,
        newImage = function() return obj({ setFilter = function() end, replacePixels = function() end }) end,
        newMesh = function() return obj({ setVertices = function() end, setVertexMap = function() end, setTexture = function() end, setDrawRange = function() end }) end,
        push = function() end, pop = function() end, setBlendMode = function() end, setColor = function() end,
        translate = function() end, setScissor = function() end, draw = function() MOCK_DRAWS = (MOCK_DRAWS or 0) + 1 end,
    },
    image = { newImageData = function(w, h) return bytedata(w * h * 4) end },
    data = { newByteData = function(n) return bytedata(n) end },
    keyboard = { isDown = function() return false end, setTextInput = function() end, setKeyRepeat = function() end },
    mouse = { setCursor = function() end, getSystemCursor = function() return {} end, setVisible = function() end },
    system = { getClipboardText = function() return "" end, setClipboardText = function() end, openURL = function() end },
    filesystem = { getInfo = function() return nil end, read = function() return nil end },
}
