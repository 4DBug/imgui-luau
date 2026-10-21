-- Patches: Luau/Roblox-tuned replacements of hot library internals, installed when the backend loads.
-- The library sources stay a 1:1 port (and run on LÖVE); these versions use buffers, typed natives and specialized fast
-- paths instead. Every patch must be exactly equivalent (same draw data, IDs, pixels): uncommon cases are handed back to
-- the original function. Only method tables / globals the callers look up at call time are replaced (MT.*), never a
-- library local. Enabled holds one switch per patch (bisecting: set one to false and rebuild; M.Set() switches at run
-- time for A/B timing).

local M = {}
M.Enabled = {
    RenderText = true, -- MT.ImFont.RenderText: Lua string, no CPU fine clip
    AddText = true,    -- MT.ImDrawList.AddText: same, calling the RenderText core directly
    CalcTextSize = true, -- ImFontCalcTextSizeXY: cache hit of an unwrapped whole string, checked first
}

local MT = ImGui.GetMetatables()
local byte, floor = string.byte, math.floor
local band, bor = bit32.band, bit32.bor
local writef64, writeu32 = buffer.writef64, buffer.writeu32

local IM_FONTGLYPH_INDEX_UNUSED    = 0xFFFF -- same values as imgui_draw.lua's locals
local IM_FONTGLYPH_INDEX_NOT_FOUND = 0xFFFE

------------------------------------------------------------------------------------------------------------------------
-- Text: ImFont:RenderText() for a Lua string without CPU fine clip (and < 10k bytes unless wrapped) as one function
-- taking the clip rect as numbers, PrimReserve() inlined, no fine clip branches in the glyph loop. Same vertex/index
-- writes in the same order. ImDrawList:AddText() calls it directly (no clip rect copy, one call less).
------------------------------------------------------------------------------------------------------------------------
local RenderText_Orig = MT.ImFont.RenderText
local AddText_Orig = MT.ImDrawList.AddText
local text_clip_rect = ImVec4() -- only for the texture-change fallback

-- imgui_draw.lua's local ImTextCalcWordWrapNextLineStart() for a Lua string: trim trailing blanks, skip one '\n'
local function WordWrapNextLineStart(text: string, pos: number, text_end: number, flags: number): number
    if band(flags, ImDrawTextFlags.WrapKeepBlanks) == 0 then
        while pos < text_end do
            local c = byte(text, pos)
            if c ~= 32 and c ~= 9 then break end
            pos += 1
        end
    end
    if pos < text_end and byte(text, pos) == 10 then
        pos += 1
    end
    return pos
end

-- Returns false (nothing done) when the original must handle it: CPU fine clip, or unloaded glyphs changed the texture
@native
local function RenderTextCore(font, draw_list, size: number, x: number, y: number, col: number, clip_x1: number, clip_y1: number, clip_x2: number, clip_y2: number, text: string, s: number, text_end: number, wrap_width: number, flags: number): boolean
    if y > clip_y2 then
        return true
    end
    flags = bor(flags, draw_list.Flags)
    if band(flags, ImDrawTextFlags.CpuFineClip) ~= 0 then
        return false
    end
    if band(flags, ImDrawFlags.TextNoPixelSnap) == 0 then
        x = floor(x)
        y = floor(y)
    end

    local baked = font.LastBaked
    if not (baked and baked.Size == floor(size + 0.5) and baked.RasterizerDensity == font.CurrentRasterizerDensity) then
        baked = font:GetFontBaked(size)
    end
    local scale: number = size / baked.Size
    local origin_x = x
    local line_height = size
    local word_wrap_enabled = wrap_width > 0.0

    -- Fast-forward to first visible line
    if y + line_height < clip_y1 then
        while y + line_height < clip_y1 and s < text_end do
            local line_end = ImMemchr(text, '\n', s)
            if word_wrap_enabled then
                s = ImFontCalcWordWrapPositionEx(font, size, text, s, (line_end ~= nil) and line_end or text_end, wrap_width, flags)
                s = WordWrapNextLineStart(text, s, text_end, flags)
            else
                s = (line_end ~= nil) and (line_end + 1) or text_end
            end
            y = y + line_height
        end
    end
    if s == text_end then
        return true
    end

    local vtx_count_max = (text_end - s) * 4
    local idx_count_max = (text_end - s) * 6
    -- PrimReserve(idx_count_max, vtx_count_max) inlined
    if (draw_list._VtxCurrentIdx + vtx_count_max >= 65536) and (band(draw_list.Flags, ImDrawFlags.UseVtxOffset) ~= 0) then
        draw_list._CmdHeader.VtxOffset = draw_list.VtxBuffer.Size + 1
        draw_list:_OnChangedVtxOffset()
    end
    local cmd_buffer = draw_list.CmdBuffer
    local cmd_count = cmd_buffer.Size
    local draw_cmd = cmd_buffer.Data[cmd_count]
    local elem_count = draw_cmd.ElemCount + idx_count_max
    draw_cmd.ElemCount = elem_count
    local vtx_buffer = draw_list.VtxBuffer
    local vtx_write: number = vtx_buffer.Size + 1
    local vtx_new_size = vtx_write - 1 + vtx_count_max
    if vtx_new_size > vtx_buffer.Capacity then vtx_buffer:resize(vtx_new_size) else vtx_buffer.Size = vtx_new_size end
    local idx_buffer = draw_list.IdxBuffer
    local idx_write: number = idx_buffer.Size + 1
    local idx_new_size = idx_write - 1 + idx_count_max
    if idx_new_size > idx_buffer.Capacity then idx_buffer:resize(idx_new_size) else idx_buffer.Size = idx_new_size end
    local idx_begin = idx_write

    local vtx_index: number = draw_list._VtxCurrentIdx
    local idx_data = idx_buffer.Data
    local vtx_data: buffer = vtx_buffer.Buf
    local color_untinted = bor(col, 0x00FFFFFF)
    local lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data
    local word_wrap_eol: number? = nil

    while s < text_end do
        if word_wrap_enabled then
            if not word_wrap_eol then
                word_wrap_eol = ImFontCalcWordWrapPositionEx(font, size, text, s, text_end, wrap_width - (x - origin_x), flags)
                lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data
            end
            if s >= word_wrap_eol then
                x = origin_x
                y += line_height
                if y > clip_y2 then
                    break
                end
                word_wrap_eol = nil
                s = WordWrapNextLineStart(text, s, text_end, flags) -- Wrapping skips upcoming blanks
                continue
            end
        end
        local c: number = byte(text, s)
        if c < 0x80 then
            s += 1
        else
            local wanted, out_char = ImStd.ImTextCharFromUtf8(text, s, text_end)
            c = out_char
            s += wanted
        end
        if c < 32 then
            if c == 10 then
                x = origin_x
                y += line_height
                if y > clip_y2 then
                    break
                end
                continue
            end
            if c == 13 then
                continue
            end
        end

        local glyph
        local gi = (c < lookup_n) and lookup[c + 1] or nil
        if gi ~= nil and gi ~= IM_FONTGLYPH_INDEX_NOT_FOUND and gi ~= IM_FONTGLYPH_INDEX_UNUSED then
            glyph = glyphs[gi]
        else
            glyph = baked:FindGlyph(c)
            lookup, lookup_n, glyphs = baked.IndexLookup.Data, baked.IndexLookup.Size, baked.Glyphs.Data
        end

        local char_width: number = glyph.AdvanceX * scale
        if glyph.Visible then
            local x1: number = x + glyph.X0 * scale
            local x2: number = x + glyph.X1 * scale
            if x1 <= clip_x2 and x2 >= clip_x1 then
                local y1: number = y + glyph.Y0 * scale
                local y2: number = y + glyph.Y1 * scale
                local u1: number, v1: number, u2: number, v2: number = glyph.U0, glyph.V0, glyph.U1, glyph.V1
                local glyph_col = glyph.Colored and color_untinted or col
                local o = (vtx_write - 1) * 36
                writef64(vtx_data, o, x1); writef64(vtx_data, o + 8, y1); writef64(vtx_data, o + 16, u1); writef64(vtx_data, o + 24, v1); writeu32(vtx_data, o + 32, glyph_col)
                writef64(vtx_data, o + 36, x2); writef64(vtx_data, o + 44, y1); writef64(vtx_data, o + 52, u2); writef64(vtx_data, o + 60, v1); writeu32(vtx_data, o + 68, glyph_col)
                writef64(vtx_data, o + 72, x2); writef64(vtx_data, o + 80, y2); writef64(vtx_data, o + 88, u2); writef64(vtx_data, o + 96, v2); writeu32(vtx_data, o + 104, glyph_col)
                writef64(vtx_data, o + 108, x1); writef64(vtx_data, o + 116, y2); writef64(vtx_data, o + 124, u1); writef64(vtx_data, o + 132, v2); writeu32(vtx_data, o + 140, glyph_col)
                idx_data[idx_write] = vtx_index; idx_data[idx_write + 1] = vtx_index + 1; idx_data[idx_write + 2] = vtx_index + 2
                idx_data[idx_write + 3] = vtx_index; idx_data[idx_write + 4] = vtx_index + 2; idx_data[idx_write + 5] = vtx_index + 3
                vtx_write += 4
                vtx_index += 4
                idx_write += 6
            end
        end
        x += char_width
    end

    if cmd_count ~= cmd_buffer.Size then
        -- Unloaded glyphs changed the texture: undo (like the original's edge case), the caller redoes it with the original
        IM_ASSERT(cmd_buffer.Data[cmd_buffer.Size].ElemCount == 0)
        cmd_buffer:pop_back()
        draw_list:PrimUnreserve(idx_count_max, vtx_count_max)
        draw_list:AddDrawCmd()
        return false
    end

    -- Give back unused vertices (clipped ones, blanks)
    vtx_buffer.Size = vtx_write - 1
    idx_buffer.Size = idx_write - 1
    draw_cmd.ElemCount = elem_count - (idx_count_max - (idx_write - idx_begin))
    draw_list._VtxWritePtr = vtx_write
    draw_list._IdxWritePtr = idx_write
    draw_list._VtxCurrentIdx = vtx_index
    return true
end

@native
local function RenderText(self, draw_list, size: number, pos, col: number, clip_rect, text, text_begin: number, text_end: number, wrap_width: number?, flags: number?)
    if type(text) ~= "string" or (text_end - text_begin > 1e4 and not (wrap_width ~= nil and wrap_width > 0.0))
        or not RenderTextCore(self, draw_list, size, pos.x, pos.y, col, clip_rect.x, clip_rect.y, clip_rect.z, clip_rect.w, text, text_begin, text_end, wrap_width or 0.0, flags or 0) then
        return RenderText_Orig(self, draw_list, size, pos, col, clip_rect, text, text_begin, text_end, wrap_width, flags)
    end
end

@native
local function AddText(self, font, font_size, pos, col, text, text_begin, text_end, wrap_width, cpu_fine_clip_rect)
    if cpu_fine_clip_rect ~= nil or type(text) ~= "string" or text_end == nil
        or (type(font) == "table" and type(font[1]) == "number") then
        return AddText_Orig(self, font, font_size, pos, col, text, text_begin, text_end, wrap_width, cpu_fine_clip_rect)
    end
    if text_begin == nil then text_begin = 1 end
    if band(col, 0xFF000000) == 0 or text_begin == text_end then
        return
    end
    if font == nil then
        font = self._Data.Font
    end
    if font_size == 0.0 then
        font_size = self._Data.FontSize
    end
    local cr = self._CmdHeader.ClipRect
    if (text_end - text_begin > 1e4 and not (wrap_width ~= nil and wrap_width > 0.0))
        or not RenderTextCore(font, self, font_size, pos.x, pos.y, col, cr.x, cr.y, cr.z, cr.w, text, text_begin, text_end, wrap_width or 0.0, 0) then
        local clip_rect = text_clip_rect
        clip_rect.x = cr.x; clip_rect.y = cr.y; clip_rect.z = cr.z; clip_rect.w = cr.w
        RenderText_Orig(font, self, font_size, pos, col, clip_rect, text, text_begin, text_end, wrap_width, 0)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- CalcTextSize: ImFontCalcTextSizeXY() answers most calls from its per baked font cache (whole string, no wrap/limit);
-- check that case first, with the same conditions, and hand everything else to the original.
------------------------------------------------------------------------------------------------------------------------
local CalcTextSizeXY_Orig = ImFontCalcTextSizeXY
local TEXT_SIZE_CACHE_MAX = 4096 -- imgui_draw.lua's local: a full cache is reset by the original before looking up

@native
local function CalcTextSizeXY(font, size: number, max_width: number, wrap_width: number, text, text_begin, text_end_display, text_end, out_offset, flags)
    if wrap_width <= 0.0 and text_begin == 1 and type(text) == "string" and out_offset == nil and max_width >= FLT_MAX
        and (flags == nil or band(flags, ImDrawTextFlags.StopOnNewLine) == 0) then
        local baked = font.LastBaked
        if baked and baked.Size == floor(size + 0.5) and baked.RasterizerDensity == font.CurrentRasterizerDensity then
            local cache = baked._TextSizeCache
            if cache ~= nil and baked._TextSizeCacheN < TEXT_SIZE_CACHE_MAX then
                local e = cache[text]
                if e then
                    local text_len1 = string.len(text) + 1
                    if (text_end == nil or text_end == text_len1) and (text_end_display == nil or text_end_display == text_len1) then
                        return e[1] * (size / baked.Size), e[2] * size, text_len1
                    end
                end
            end
        end
    end
    return CalcTextSizeXY_Orig(font, size, max_width, wrap_width, text, text_begin, text_end_display, text_end, out_offset, flags)
end

------------------------------------------------------------------------------------------------------------------------
-- name -> function(on) installing the patch or restoring the original
local Install = {
    RenderText = function(on) MT.ImFont.RenderText = on and RenderText or RenderText_Orig end,
    AddText = function(on) MT.ImDrawList.AddText = on and AddText or AddText_Orig end,
    CalcTextSize = function(on) ImFontCalcTextSizeXY = on and CalcTextSizeXY or CalcTextSizeXY_Orig end,
}
-- Switches a patch at run time (tests time both versions in one process)
function M.Set(name: string, on: boolean)
    Install[name](on)
end
for name in Install do
    M.Set(name, M.Enabled[name])
end

return M
