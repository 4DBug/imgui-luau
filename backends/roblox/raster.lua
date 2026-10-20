-- Software rasterizer: pure buffer code shared by the backend and the parallel worker (inlined into ImGuiWorker).
-- Target: RGBA8 row-major (ImU32 is already R | G<<8 | B<<16 | A<<24), non-premultiplied "over" onto transparent.
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local readu8, readu32, writeu32 = buffer.readu8, buffer.readu32, buffer.writeu32
local readf64 = buffer.readf64
local band, rshift = bit32.band, bit32.rshift
local readi32 = buffer.readi32

local M = {
    TILE = 128,
    -- Packed jobs (parallel executor -> worker), per Actor and flush: P = primitive records, T = tile jobs.
    -- P record (REC bytes): kind (0 triangle, 1 rect, 2/3 gradient kind 1/2, 4 line quad), tex id (-1: none),
    --   clip x0 y0 x1 y1, bounds x0 y0 x1 y1 (screen pixels, i32), then raw vertices (VTX bytes: x y u v f64,
    --   col u32): a at REC_A, c at REC_C, b at REC_B, d at REC_D.
    -- T job: tox toy (f64), x0 y0 nr count (i32), nr x rect x0 y0 x1 y1 (i32, tile pixels), count x P offset (i32).
    VTX = 36, REC = 184, REC_A = 40, REC_C = 76, REC_B = 112, REC_D = 148, JOB = 32,
}
local TILE = M.TILE

-- Pixel (x, y) of the target is at byte (y * TargetWidth + x) * 4 + TargetBase: a target can be a sub-rectangle of the
-- tile (raster straight into the upload buffer)
local TargetBuffer: buffer, TargetWidth, TargetBase = buffer.create(0), 0, 0
local PrevRow = buffer.create(1024)

-- True when TargetBuffer[o, o + len) equals the previous row's destination (so its result can be copied); else
-- remembers this row. u32 loop, not readstring ==: that allocated a string per row.
@native
local function RowRepeats(o: number, len: number, has_prev: boolean): boolean
    if has_prev then
        local same = true
        for k = 0, len - 4, 4 do
            if readu32(TargetBuffer, o + k) ~= readu32(PrevRow, k) then
                same = false
                break
            end
        end
        if same then return true end
    end
    if buffer.len(PrevRow) < len then PrevRow = buffer.create(len) end
    buffer.copy(PrevRow, 0, TargetBuffer, o, len)
    return false
end
local RectColumns = table.create(256, 0)
-- DrawRect's per-alpha blend cache: GlyphKey[alpha] = GlyphGen + destination value -> GlyphValue[alpha]. GlyphGen
-- (a multiple of 2^32) changes with the vertex colour.
local GlyphKey, GlyphValue = table.create(256, -1), table.create(256, 0)
GlyphKey[0], GlyphValue[0] = -1, 0
local GlyphCol, GlyphGen = -1, 0

-- Uniform rows: [RowX0[y], RowX1[y]) of target row y holds only the pixel value RowV[y] (empty when RowX0 >= RowX1).
-- Set by ClearRect and by solid spans; shrunk by everything drawn over it. A solid span inside it blends one pixel and
-- fills (window/frame backgrounds over backgrounds), instead of blending every pixel. Rows [RowLo, RowHi) are set.
local RowX0, RowX1, RowV = table.create(TILE, 0), table.create(TILE, 0), table.create(TILE, 0)
RowX0[0], RowX1[0], RowV[0] = 0, 0, 0
local RowLo, RowHi = 0, 0

-- Drawing may change [x0, x1) x [y0, y1): keep the larger uniform piece of each row outside it
@native
local function Shrink(x0: number, y0: number, x1: number, y1: number)
    for y = y0, y1 - 1 do
        local a, b = RowX0[y], RowX1[y]
        if x0 < b and x1 > a then
            if x0 - a >= b - x1 then RowX1[y] = x0 else RowX0[y] = x1 end
        end
    end
end

-- FillSpan and DrawTriangle's flat path inline this math with per-span constants: keep them in sync.
@native
local function BlendPixel(TargetBuffer: buffer, o: number, r: number, g: number, b: number, a: number)
    if a >= 255 then
        writeu32(TargetBuffer, o, floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + 4278190080)
        return
    end
    if a <= 0 then return end
    local d = readu32(TargetBuffer, o)
    if d < 16777216 then
        writeu32(TargetBuffer, o,
            floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + floor(a + 0.5) * 16777216)
        return
    end
    local sa = a / 255
    local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
    if d >= 4278190080 then
        local ns = 1 - sa
        writeu32(TargetBuffer, o,
            floor(r * sa + dr * ns + 0.5) + floor(g * sa + dg * ns + 0.5) * 256 + floor(b * sa + db * ns + 0.5) * 65536
            + 4278190080)
    else
        local k = rshift(d, 24) * ((1 - sa) / 255)
        local oa = sa + k
        local inv = 1 / oa
        writeu32(TargetBuffer, o, floor((r * sa + dr * k) * inv + 0.5) + floor((g * sa + dg * k) * inv + 0.5) * 256
            + floor((b * sa + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216)
    end
end

-- Wide spans (>= 32 px) over non-uniform rows: rows usually blend over identical rows, so a row whose destination
-- repeats the previous one's copies its result
@native
local function FillSpan(TargetBuffer: buffer, y0: number, y1: number, x0: number, x1: number, r: number, g: number,
    b: number, a: number)
    if a <= 0 then return end
    local w4 = (x1 - x0 - 1) * 4
    local span = x1 - x0
    if a >= 255 then
        local packed = floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + 4278190080
        local first = (y0 * TargetWidth + x0) * 4 + TargetBase
        for o = first, first + w4, 4 do writeu32(TargetBuffer, o, packed) end
        for y = y0 + 1, y1 - 1 do buffer.copy(TargetBuffer, (y * TargetWidth + x0) * 4 + TargetBase, TargetBuffer, first, w4 + 4) end
        -- now uniform: per row keep whichever piece is larger
        for y = y0, y1 - 1 do
            local ra, rb = RowX0[y], RowX1[y]
            if x0 < rb and x1 > ra then
                if x0 - ra >= rb - x1 then rb = x0 else ra = x1 end
            end
            if span > rb - ra then RowX0[y], RowX1[y], RowV[y] = x0, x1, packed else RowX0[y], RowX1[y] = ra, rb end
        end
        return
    end
    local packed0 = floor(r + 0.5) + floor(g + 0.5) * 256 + floor(b + 0.5) * 65536 + floor(a + 0.5) * 16777216
    local sa = a / 255
    local ns = 1 - sa
    local c1 = ns / 255
    local rs, gs, bs = r * sa, g * sa, b * sa
    local last_d, last_v = -1, 0 -- UI backgrounds are mostly flat: reuse the previous result for the same destination
    local prev_o, prev_v = 0, -1 -- previous row: filled with prev_v (-1: blended)
    local wide, has_prev = span >= 32 and y1 - y0 > 1, false
    for y = y0, y1 - 1 do
        local o0 = (y * TargetWidth + x0) * 4 + TargetBase
        local ra, rb = RowX0[y], RowX1[y]
        if x0 >= ra and x1 <= rb then
            -- over one value: the per-pixel result for d = RowV[y], then fill
            local d = RowV[y]
            if d ~= last_d then
                last_d = d
                if d < 16777216 then
                    last_v = packed0
                else
                    local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
                    if d >= 4278190080 then
                        last_v = floor(rs + dr * ns + 0.5) + floor(gs + dg * ns + 0.5) * 256
                            + floor(bs + db * ns + 0.5) * 65536 + 4278190080
                    else
                        local k = rshift(d, 24) * c1
                        local oa = sa + k
                        local inv = 1 / oa
                        last_v = floor((rs + dr * k) * inv + 0.5) + floor((gs + dg * k) * inv + 0.5) * 256
                            + floor((bs + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216
                    end
                end
            end
            local v = last_v
            if v == prev_v and span > 8 then -- (a call: slower than a few writes)
                buffer.copy(TargetBuffer, o0, TargetBuffer, prev_o, w4 + 4)
            else
                for o = o0, o0 + w4, 4 do writeu32(TargetBuffer, o, v) end
            end
            prev_o, prev_v, has_prev = o0, v, false
            if span >= x0 - ra and span >= rb - x1 then
                RowX0[y], RowX1[y], RowV[y] = x0, x1, v
            elseif x0 - ra >= rb - x1 then
                RowX1[y] = x0
            else
                RowX0[y] = x1
            end
            continue
        end
        if x0 < rb and x1 > ra then
            if x0 - ra >= rb - x1 then RowX1[y] = x0 else RowX0[y] = x1 end
        end
        if wide then
            local repeats = RowRepeats(o0, w4 + 4, has_prev)
            has_prev = true
            if repeats then
                buffer.copy(TargetBuffer, o0, TargetBuffer, prev_o, w4 + 4)
                prev_o, prev_v = o0, -1
                continue
            end
        end
        prev_o, prev_v = o0, -1
        for o = o0, o0 + w4, 4 do
            local d = readu32(TargetBuffer, o)
            if d == last_d then
                writeu32(TargetBuffer, o, last_v)
            elseif d < 16777216 then
                writeu32(TargetBuffer, o, packed0)
            else
                last_d = d
                local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
                if d >= 4278190080 then
                    last_v = floor(rs + dr * ns + 0.5) + floor(gs + dg * ns + 0.5) * 256
                        + floor(bs + db * ns + 0.5) * 65536 + 4278190080
                else
                    local k = rshift(d, 24) * c1
                    local oa = sa + k
                    local inv = 1 / oa
                    last_v = floor((rs + dr * k) * inv + 0.5) + floor((gs + dg * k) * inv + 0.5) * 256
                        + floor((bs + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216
                end
                writeu32(TargetBuffer, o, last_v)
            end
        end
    end
end

@native
local function UnpackColor(col: number)
    return col % 256, floor(col / 256) % 256, floor(col / 65536) % 256, floor(col / 16777216) % 256
end

@native
local function SampleTexture(t, u: number, v: number)
    local tw, th = t.Width, t.Height
    local tx, ty = floor(u * tw), floor(v * th)
    if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
    if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
    local o = (ty * tw + tx) * 4
    local tb = t.Buffer
    return readu8(tb, o), readu8(tb, o + 1), readu8(tb, o + 2), readu8(tb, o + 3)
end

@native
local function DrawRect(TargetBuffer: buffer, x0: number, y0: number, x1: number, y1: number, u0: number, v0: number,
    u1: number, v1: number, col: number, t, cx0: number, cy0: number, cx1: number, cy1: number)
    local r, g, b, a = UnpackColor(col)
    if a == 0 then return end
    local px0, py0 = max(ceil(x0 - 0.5), cx0), max(ceil(y0 - 0.5), cy0)
    local px1, py1 = min(ceil(x1 - 0.5), cx1), min(ceil(y1 - 0.5), cy1)
    if px0 >= px1 or py0 >= py1 then return end

    if not t or (u0 == u1 and v0 == v1) then
        if t then
            local tr, tg, tb, ta = SampleTexture(t, u0, v0)
            r, g, b, a = r * tr / 255, g * tg / 255, b * tb / 255, a * ta / 255
        end
        if a <= 0 then return end
        FillSpan(TargetBuffer, py0, py1, px0, px1, r, g, b, a)
        return
    end

    Shrink(px0, py0, px1, py1)
    local du, dv = (u1 - u0) / (x1 - x0), (v1 - v0) / (y1 - y0)
    local tw: number, th: number, tbuf: buffer, dbuf: buffer = t.Width, t.Height, t.Buffer, TargetBuffer
    local r255, g255, b255, a255 = r / 255, g / 255, b / 255, a / 255
    local ncol = px1 - px0
    local cols = RectColumns
    local ident = col == 4294967295
    local last_tv, sa, sr, sg, sb, s_opaque, fa, fn, fk = -1, 0, 0, 0, 0, 0, 0, 0, 0
    local step = true
    for c = 1, ncol do
        local tx = floor((u0 + (px0 + c - 1 + 0.5 - x0) * du) * tw)
        if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
        cols[c] = tx * 4
        if c > 1 and tx * 4 ~= cols[c - 1] + 4 then step = false end
    end
    -- white translucent texels (font atlas): blend result cached per alpha for one destination value and colour
    if col ~= GlyphCol then
        GlyphCol = col
        GlyphGen += 4294967296
        if GlyphGen >= 4503599627370496 then -- 2^52: keys must stay exact
            GlyphGen = 4294967296
            for k = 0, 255 do GlyphKey[k] = -1 end
        end
    end
    local gen = GlyphGen
    for y = py0, py1 - 1 do
        local ty = floor((v0 + (y + 0.5 - y0) * dv) * th)
        if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
        local trow4 = ty * tw * 4
        local o = (y * TargetWidth + px0) * 4 + TargetBase
        local tb0 = trow4 + cols[1] - 4
        for c = 1, ncol do
            local tv = readu32(tbuf, step and tb0 + c * 4 or trow4 + cols[c])
            if tv < 16777216 then
                o += 4
                continue
            end
            if ident and tv >= 4278190080 then -- white opaque vertex colour: an opaque texel is the result
                writeu32(dbuf, o, tv)
                o += 4
                continue
            end
            local d, key, al = 0, -1, 0
            if tv % 16777216 == 16777215 then
                al = rshift(tv, 24)
                d = readu32(dbuf, o)
                key = gen + d
                if GlyphKey[al] == key then
                    writeu32(dbuf, o, GlyphValue[al])
                    o += 4
                    continue
                end
            end
            -- BlendPixel inlined (same math)
            if tv ~= last_tv then
                last_tv = tv
                sa = rshift(tv, 24) * a255
                sr, sg, sb = band(tv, 255) * r255, band(rshift(tv, 8), 255) * g255, band(rshift(tv, 16), 255) * b255
                s_opaque = floor(sr + 0.5) + floor(sg + 0.5) * 256 + floor(sb + 0.5) * 65536
                fa = sa / 255
                fn = 1 - fa
                fk = (1 - fa) / 255
            end
            local v = -1
            if sa >= 255 then
                v = s_opaque + 4278190080
            elseif sa > 0 then
                if key < 0 then d = readu32(dbuf, o) end
                if d < 16777216 then
                    v = s_opaque + floor(sa + 0.5) * 16777216
                else
                    local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
                    if d >= 4278190080 then
                        v = floor(sr * fa + dr * fn + 0.5) + floor(sg * fa + dg * fn + 0.5) * 256
                            + floor(sb * fa + db * fn + 0.5) * 65536 + 4278190080
                    else
                        local k = rshift(d, 24) * fk
                        local oa = fa + k
                        local inv = 1 / oa
                        v = floor((sr * fa + dr * k) * inv + 0.5) + floor((sg * fa + dg * k) * inv + 0.5) * 256
                            + floor((sb * fa + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216
                    end
                end
            end
            if v >= 0 then
                writeu32(dbuf, o, v)
            elseif key >= 0 then
                v = d -- unchanged
            end
            if key >= 0 then
                GlyphKey[al], GlyphValue[al] = key, v
            end
            o += 4
        end
    end
end

@native
local function DrawTriangle(dbuf: buffer, vbuf: buffer, va: number, vb: number, vc: number, t, cx0: number, cy0: number,
    cx1: number, cy1: number, ox: number, oy: number)
    local x0, y0 = readf64(vbuf, va) - ox, readf64(vbuf, va + 8) - oy
    local x1, y1 = readf64(vbuf, vb) - ox, readf64(vbuf, vb + 8) - oy
    local x2, y2 = readf64(vbuf, vc) - ox, readf64(vbuf, vc + 8) - oy
    local area = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
    if area == 0 then return end
    if area < 0 then
        vb, vc = vc, vb
        x1, y1, x2, y2 = x2, y2, x1, y1
        area = -area
    end

    local minx, maxx = max(floor(min(x0, x1, x2)), cx0), min(ceil(max(x0, x1, x2)), cx1 - 1)
    local miny, maxy = max(floor(min(y0, y1, y2)), cy0), min(ceil(max(y0, y1, y2)), cy1 - 1)
    if minx > maxx or miny > maxy then return end

    local A0, B0 = y1 - y2, x2 - x1
    local C0 = -(A0 * x1 + B0 * y1)
    local A1, B1 = y2 - y0, x0 - x2
    local C1 = -(A1 * x2 + B1 * y2)
    local A2, B2 = y0 - y1, x1 - x0
    local C2 = -(A2 * x0 + B2 * y0)
    local tl0 = A0 > 0 or (A0 == 0 and B0 > 0)
    local tl1 = A1 > 0 or (A1 == 0 and B1 > 0)
    local tl2 = A2 > 0 or (A2 == 0 and B2 > 0)

    local inv = 1 / area
    local n0, n1, n2 = A0 ~= 0 and -1 / A0 or 0, A1 ~= 0 and -1 / A1 or 0, A2 ~= 0 and -1 / A2 or 0
    local ra, ga, ba, aa = UnpackColor(readu32(vbuf, va + 32))
    local rb, gb, bb, ab = UnpackColor(readu32(vbuf, vb + 32))
    local rc, gc, bc, ac = UnpackColor(readu32(vbuf, vc + 32))
    local ua, vva, ub, vvb, uc, vvc = readf64(vbuf, va + 16), readf64(vbuf, va + 24), readf64(vbuf, vb + 16),
        readf64(vbuf, vb + 24), readf64(vbuf, vc + 16), readf64(vbuf, vc + 24)

    local textured = t and not (ua == ub and ua == uc and vva == vvb and vva == vvc)
    if t and not textured then -- constant uv (atlas white pixel): fold the texel into the vertex colours
        local tr, tg, tb, ta = SampleTexture(t, ua, vva)
        ra, ga, ba, aa = ra * tr / 255, ga * tg / 255, ba * tb / 255, aa * ta / 255
        rb, gb, bb, ab = rb * tr / 255, gb * tg / 255, bb * tb / 255, ab * ta / 255
        rc, gc, bc, ac = rc * tr / 255, gc * tg / 255, bc * tb / 255, ac * ta / 255
    end
    local flat = not textured and ra == rb and ra == rc and ga == gb and ga == gc and ba == bb and ba == bc and aa == ab
        and aa == ac
    if flat and aa <= 0 then return end
    local f_opaque, f_packed, f_sa, f_ns, f_c1, f_rs, f_gs, f_bs = false, 0, 0, 0, 0, 0, 0, 0
    if flat then
        f_opaque = aa >= 255
        f_packed = floor(ra + 0.5) + floor(ga + 0.5) * 256 + floor(ba + 0.5) * 65536
            + (f_opaque and 4278190080 or floor(aa + 0.5) * 16777216)
        f_sa = aa / 255
        f_ns = 1 - f_sa
        f_c1 = f_ns / 255
        f_rs, f_gs, f_bs = ra * f_sa, ga * f_sa, ba * f_sa
    end
    local cconst = textured and ra == rb and ra == rc and ga == gb and ga == gc and ba == bb and ba == bc and aa == ab
        and aa == ac
    if cconst and aa <= 0 then return end
    local tw: number, th: number, tbuf: buffer = 0, 0, dbuf
    local r255, g255, b255, a255 = ra / 255, ga / 255, ba / 255, aa / 255
    local last_tv, sa, sr, sg, sb, s_opaque, fa, fn, fk = -1, 0, 0, 0, 0, 0, 0, 0, 0
    if cconst then tw, th, tbuf = t.Width, t.Height, t.Buffer end

    if not textured and (maxx - minx) * 2 < maxy - miny then
        -- tall sliver (vertical AA fringe): walk columns, same per-pixel edge and colour math as the rows below (each
        -- pixel blended once, so the order does not matter): no empty-row passes
        local m0, m1, m2 = B0 ~= 0 and -1 / B0 or 0, B1 ~= 0 and -1 / B1 or 0, B2 ~= 0 and -1 / B2 or 0
        local stride = TargetWidth * 4
        Shrink(minx, miny, maxx + 1, maxy + 1)
        for x = minx, maxx do
            local px = x + 0.5
            local yt, yb = miny, maxy
            local f0, f1, f2 = A0 * px + C0, A1 * px + C1, A2 * px + C2
            if B0 > 0 then yt = max(yt, floor(f0 * m0 - 0.500001)) elseif B0 < 0 then yb = min(yb, ceil(f0 * m0 - 0.499999)) end
            if B1 > 0 then yt = max(yt, floor(f1 * m1 - 0.500001)) elseif B1 < 0 then yb = min(yb, ceil(f1 * m1 - 0.499999)) end
            if B2 > 0 then yt = max(yt, floor(f2 * m2 - 0.500001)) elseif B2 < 0 then yb = min(yb, ceil(f2 * m2 - 0.499999)) end
            while yt <= yb do
                local py = yt + 0.5
                local w0, w1, w2 = A0 * px + (B0 * py + C0), A1 * px + (B1 * py + C1), A2 * px + (B2 * py + C2)
                if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2)) then
                    break
                end
                yt += 1
            end
            while yb > yt do
                local py = yb + 0.5
                local w0, w1, w2 = A0 * px + (B0 * py + C0), A1 * px + (B1 * py + C1), A2 * px + (B2 * py + C2)
                if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2)) then
                    break
                end
                yb -= 1
            end
            if yt > yb then continue end
            local o = (yt * TargetWidth + x) * 4 + TargetBase
            if flat then
                for _ = yt, yb do
                    BlendPixel(dbuf, o, ra, ga, ba, aa)
                    o += stride
                end
                continue
            end
            for y = yt, yb do
                local py = y + 0.5
                local w0, w1, w2 = (A0 * px + (B0 * py + C0)) * inv, (A1 * px + (B1 * py + C1)) * inv,
                    (A2 * px + (B2 * py + C2)) * inv
                local a = w0 * aa + w1 * ab + w2 * ac
                if a > 0 then
                    BlendPixel(dbuf, o, w0 * ra + w1 * rb + w2 * rc, w0 * ga + w1 * gb + w2 * gc, w0 * ba + w1 * bb + w2 * bc, a)
                end
                o += stride
            end
        end
        return
    end

    for y = miny, maxy do
        local py = y + 0.5
        local xl, xr = minx, maxx
        local e0, e1, e2 = B0 * py + C0, B1 * py + C1, B2 * py + C2
        -- (e * n is -e / A within an ulp; the 1e-6 margin covers that, and the exact tests below decide)
        if A0 > 0 then
            xl = max(xl, floor(e0 * n0 - 0.500001))
        elseif A0 < 0 then
            xr = min(xr, ceil(e0 * n0 - 0.499999))
        end
        if A1 > 0 then
            xl = max(xl, floor(e1 * n1 - 0.500001))
        elseif A1 < 0 then
            xr = min(xr, ceil(e1 * n1 - 0.499999))
        end
        if A2 > 0 then
            xl = max(xl, floor(e2 * n2 - 0.500001))
        elseif A2 < 0 then
            xr = min(xr, ceil(e2 * n2 - 0.499999))
        end

        while xl <= xr do
            local px = xl + 0.5
            local w0, w1, w2 = A0 * px + e0, A1 * px + e1, A2 * px + e2
            if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2)) then
                break
            end
            xl += 1
        end
        while xr > xl do
            local px = xr + 0.5
            local w0, w1, w2 = A0 * px + e0, A1 * px + e1, A2 * px + e2
            if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2)) then
                break
            end
            xr -= 1
        end
        if xl > xr then continue end
        local ra_, rb_ = RowX0[y], RowX1[y] -- Shrink for this row's span
        if xl < rb_ and xr >= ra_ then
            if xl - ra_ >= rb_ - xr - 1 then RowX1[y] = xl else RowX0[y] = xr + 1 end
        end
        local o = (y * TargetWidth + xl) * 4 + TargetBase
        if flat then
            local o1 = o + (xr - xl) * 4
            if f_opaque then
                for oo = o, o1, 4 do writeu32(dbuf, oo, f_packed) end
                continue
            end
            local last_d, last_v = -1, 0
            for oo = o, o1, 4 do
                local d = readu32(dbuf, oo)
                if d == last_d then
                    writeu32(dbuf, oo, last_v)
                elseif d < 16777216 then
                    writeu32(dbuf, oo, f_packed)
                else
                    last_d = d
                    local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
                    if d >= 4278190080 then
                        last_v = floor(f_rs + dr * f_ns + 0.5) + floor(f_gs + dg * f_ns + 0.5) * 256
                            + floor(f_bs + db * f_ns + 0.5) * 65536 + 4278190080
                    else
                        local k = rshift(d, 24) * f_c1
                        local oa = f_sa + k
                        local inv = 1 / oa
                        last_v = floor((f_rs + dr * k) * inv + 0.5) + floor((f_gs + dg * k) * inv + 0.5) * 256
                            + floor((f_bs + db * k) * inv + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216
                    end
                    writeu32(dbuf, oo, last_v)
                end
            end
            continue
        end
        if cconst then
            -- constant vertex colour, varying uv (AA line textures): texel read as u32, blend cached per texel value
            for x = xl, xr do
                local px = x + 0.5
                local w0, w1, w2 = (A0 * px + e0) * inv, (A1 * px + e1) * inv, (A2 * px + e2) * inv
                local tx, ty = floor((w0 * ua + w1 * ub + w2 * uc) * tw), floor((w0 * vva + w1 * vvb + w2 * vvc) * th)
                if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
                if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
                local tv = readu32(tbuf, (ty * tw + tx) * 4)
                if tv ~= last_tv then
                    last_tv = tv
                    sa = rshift(tv, 24) * a255
                    sr, sg, sb = band(tv, 255) * r255, band(rshift(tv, 8), 255) * g255, band(rshift(tv, 16), 255) * b255
                    s_opaque = floor(sr + 0.5) + floor(sg + 0.5) * 256 + floor(sb + 0.5) * 65536
                    fa = sa / 255
                    fn = 1 - fa
                    fk = (1 - fa) / 255
                end
                -- BlendPixel inlined (same math)
                if sa >= 255 then
                    writeu32(dbuf, o, s_opaque + 4278190080)
                elseif sa > 0 then
                    local d = readu32(dbuf, o)
                    if d < 16777216 then
                        writeu32(dbuf, o, s_opaque + floor(sa + 0.5) * 16777216)
                    else
                        local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
                        if d >= 4278190080 then
                            writeu32(dbuf, o, floor(sr * fa + dr * fn + 0.5) + floor(sg * fa + dg * fn + 0.5) * 256
                                + floor(sb * fa + db * fn + 0.5) * 65536 + 4278190080)
                        else
                            local k = rshift(d, 24) * fk
                            local oa = fa + k
                            local inv2 = 1 / oa
                            writeu32(dbuf, o, floor((sr * fa + dr * k) * inv2 + 0.5)
                                + floor((sg * fa + dg * k) * inv2 + 0.5) * 256
                                + floor((sb * fa + db * k) * inv2 + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216)
                        end
                    end
                end
                o += 4
            end
            continue
        end
        for x = xl, xr do
            local px = x + 0.5
            local w0, w1, w2 = (A0 * px + e0) * inv, (A1 * px + e1) * inv, (A2 * px + e2) * inv
            local a = w0 * aa + w1 * ab + w2 * ac
            if textured then
                local r = w0 * ra + w1 * rb + w2 * rc
                local g = w0 * ga + w1 * gb + w2 * gc
                local b = w0 * ba + w1 * bb + w2 * bc
                local tr, tg, tb, ta = SampleTexture(t, w0 * ua + w1 * ub + w2 * uc, w0 * vva + w1 * vvb + w2 * vvc)
                BlendPixel(dbuf, o, r * tr / 255, g * tg / 255, b * tb / 255, a * ta / 255)
            elseif a > 0 then
                BlendPixel(dbuf, o, w0 * ra + w1 * rb + w2 * rc, w0 * ga + w1 * gb + w2 * gc,
                    w0 * ba + w1 * bb + w2 * bc, a)
            end
            o += 4
        end
    end
end

-- Textured line quad (triangles a b c + a c d, one colour, uv a = b and c = d: ImPlot PrimLine). Same edge functions as
-- the two DrawTriangle calls (so the same pixels), uv from triangle a b c's barycentrics over the whole quad.
@native
local function DrawLineQuad(dbuf: buffer, vbuf: buffer, va: number, vb: number, vc: number, vd: number, t,
    cx0: number, cy0: number, cx1: number, cy1: number, ox: number, oy: number)
    local x0, y0 = readf64(vbuf, va) - ox, readf64(vbuf, va + 8) - oy
    local x1, y1 = readf64(vbuf, vb) - ox, readf64(vbuf, vb + 8) - oy
    local x2, y2 = readf64(vbuf, vc) - ox, readf64(vbuf, vc + 8) - oy
    local x3, y3 = readf64(vbuf, vd) - ox, readf64(vbuf, vd + 8) - oy
    local area = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
    local area2 = (x2 - x0) * (y3 - y0) - (y2 - y0) * (x3 - x0)
    if area == 0 or area2 == 0 or (area < 0) ~= (area2 < 0) then -- degenerate or not convex: the two triangles
        DrawTriangle(dbuf, vbuf, va, vb, vc, t, cx0, cy0, cx1, cy1, ox, oy)
        DrawTriangle(dbuf, vbuf, va, vc, vd, t, cx0, cy0, cx1, cy1, ox, oy)
        return
    end
    local ua, vva, uc, vvc = readf64(vbuf, va + 16), readf64(vbuf, va + 24), readf64(vbuf, vc + 16), readf64(vbuf, vc + 24)
    -- outer edges P -> Q (quad order, counter-clockwise like DrawTriangle's swap): A = yP - yQ, B = xQ - xP, C from P
    local px_, py_, qx_, qy_ = x1, y1, x3, y3 -- b, d
    if area < 0 then
        px_, py_, qx_, qy_ = x3, y3, x1, y1
        area = -area
    end
    -- order a -> p -> c -> q
    local A0, B0 = y0 - py_, px_ - x0
    local C0 = -(A0 * x0 + B0 * y0)
    local A1, B1 = py_ - y2, x2 - px_
    local C1 = -(A1 * px_ + B1 * py_)
    local A2, B2 = y2 - qy_, qx_ - x2
    local C2 = -(A2 * x2 + B2 * y2)
    local A3, B3 = qy_ - y0, x0 - qx_
    local C3 = -(A3 * qx_ + B3 * qy_)
    local tl0 = A0 > 0 or (A0 == 0 and B0 > 0)
    local tl1 = A1 > 0 or (A1 == 0 and B1 > 0)
    local tl2 = A2 > 0 or (A2 == 0 and B2 > 0)
    local tl3 = A3 > 0 or (A3 == 0 and B3 > 0)
    local n0, n1, n2, n3 = A0 ~= 0 and -1 / A0 or 0, A1 ~= 0 and -1 / A1 or 0, A2 ~= 0 and -1 / A2 or 0,
        A3 ~= 0 and -1 / A3 or 0
    -- weight of c in triangle a b c: edge a -> b over its area (same sign whichever side b is on)
    local WA, WB = y0 - y1, x1 - x0
    local WC = -(WA * x0 + WB * y0)
    local winv = 1 / ((x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0))
    WA, WB, WC = WA * winv, WB * winv, WC * winv
    local du, dv = uc - ua, vvc - vva

    local minx, maxx = max(floor(min(x0, x1, x2, x3)), cx0), min(ceil(max(x0, x1, x2, x3)), cx1 - 1)
    local miny, maxy = max(floor(min(y0, y1, y2, y3)), cy0), min(ceil(max(y0, y1, y2, y3)), cy1 - 1)
    if minx > maxx or miny > maxy then return end
    local ra, ga, ba, aa = UnpackColor(readu32(vbuf, va + 32))
    if aa <= 0 then return end
    Shrink(minx, miny, maxx + 1, maxy + 1)
    local tw: number, th: number, tbuf: buffer = t.Width, t.Height, t.Buffer
    local r255, g255, b255, a255 = ra / 255, ga / 255, ba / 255, aa / 255
    local last_tv, sa, sr, sg, sb, s_opaque, fa, fn, fk = -1, 0, 0, 0, 0, 0, 0, 0, 0
    for y = miny, maxy do
        local py = y + 0.5
        local xl, xr = minx, maxx
        local e0, e1, e2, e3 = B0 * py + C0, B1 * py + C1, B2 * py + C2, B3 * py + C3
        if A0 > 0 then xl = max(xl, floor(e0 * n0 - 0.500001)) elseif A0 < 0 then xr = min(xr, ceil(e0 * n0 - 0.499999)) end
        if A1 > 0 then xl = max(xl, floor(e1 * n1 - 0.500001)) elseif A1 < 0 then xr = min(xr, ceil(e1 * n1 - 0.499999)) end
        if A2 > 0 then xl = max(xl, floor(e2 * n2 - 0.500001)) elseif A2 < 0 then xr = min(xr, ceil(e2 * n2 - 0.499999)) end
        if A3 > 0 then xl = max(xl, floor(e3 * n3 - 0.500001)) elseif A3 < 0 then xr = min(xr, ceil(e3 * n3 - 0.499999)) end
        while xl <= xr do
            local px = xl + 0.5
            local w0, w1, w2, w3 = A0 * px + e0, A1 * px + e1, A2 * px + e2, A3 * px + e3
            if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2))
                and (w3 > 0 or (w3 == 0 and tl3)) then
                break
            end
            xl += 1
        end
        while xr > xl do
            local px = xr + 0.5
            local w0, w1, w2, w3 = A0 * px + e0, A1 * px + e1, A2 * px + e2, A3 * px + e3
            if (w0 > 0 or (w0 == 0 and tl0)) and (w1 > 0 or (w1 == 0 and tl1)) and (w2 > 0 or (w2 == 0 and tl2))
                and (w3 > 0 or (w3 == 0 and tl3)) then
                break
            end
            xr -= 1
        end
        if xl > xr then continue end
        local o = (y * TargetWidth + xl) * 4 + TargetBase
        local wrow = WB * py + WC
        for x = xl, xr do
            local w = WA * (x + 0.5) + wrow
            local tx, ty = floor((ua + w * du) * tw), floor((vva + w * dv) * th)
            if tx < 0 then tx = 0 elseif tx >= tw then tx = tw - 1 end
            if ty < 0 then ty = 0 elseif ty >= th then ty = th - 1 end
            local tv = readu32(tbuf, (ty * tw + tx) * 4)
            if tv ~= last_tv then
                last_tv = tv
                sa = rshift(tv, 24) * a255
                sr, sg, sb = band(tv, 255) * r255, band(rshift(tv, 8), 255) * g255, band(rshift(tv, 16), 255) * b255
                s_opaque = floor(sr + 0.5) + floor(sg + 0.5) * 256 + floor(sb + 0.5) * 65536
                fa = sa / 255
                fn = 1 - fa
                fk = (1 - fa) / 255
            end
            -- BlendPixel inlined (same math)
            if sa >= 255 then
                writeu32(dbuf, o, s_opaque + 4278190080)
            elseif sa > 0 then
                local d = readu32(dbuf, o)
                if d < 16777216 then
                    writeu32(dbuf, o, s_opaque + floor(sa + 0.5) * 16777216)
                else
                    local dr, dg, db = band(d, 255), band(rshift(d, 8), 255), band(rshift(d, 16), 255)
                    if d >= 4278190080 then
                        writeu32(dbuf, o, floor(sr * fa + dr * fn + 0.5) + floor(sg * fa + dg * fn + 0.5) * 256
                            + floor(sb * fa + db * fn + 0.5) * 65536 + 4278190080)
                    else
                        local k = rshift(d, 24) * fk
                        local oa = fa + k
                        local inv2 = 1 / oa
                        writeu32(dbuf, o, floor((sr * fa + dr * k) * inv2 + 0.5)
                            + floor((sg * fa + dg * k) * inv2 + 0.5) * 256
                            + floor((sb * fa + db * k) * inv2 + 0.5) * 65536 + floor(oa * 255 + 0.5) * 16777216)
                    end
                end
            end
            o += 4
        end
    end
end

-- Linear gradient quad, constant uv. kind 1: along y (ca top, cb bottom), 2: along x. Same pixels as the triangles.
@native
local function DrawRectGradient(TargetBuffer: buffer, x0: number, y0: number, x1: number, y1: number, ca: number,
    cb: number, kind: number, t, u: number, v: number, cx0: number, cy0: number, cx1: number, cy1: number)
    local px0, py0 = max(ceil(x0 - 0.5), cx0), max(ceil(y0 - 0.5), cy0)
    local px1, py1 = min(ceil(x1 - 0.5), cx1), min(ceil(y1 - 0.5), cy1)
    if px0 >= px1 or py0 >= py1 then return end
    Shrink(px0, py0, px1, py1)
    local ra, ga, ba, aa = UnpackColor(ca)
    local rb, gb, bb, ab = UnpackColor(cb)
    if t then
        local tr, tg, tb, ta = SampleTexture(t, u, v)
        ra, ga, ba, aa = ra * tr / 255, ga * tg / 255, ba * tb / 255, aa * ta / 255
        rb, gb, bb, ab = rb * tr / 255, gb * tg / 255, bb * tb / 255, ab * ta / 255
    end
    if kind == 1 then
        local inv = 1 / (y1 - y0)
        for y = py0, py1 - 1 do
            local f = (y + 0.5 - y0) * inv
            local nf = 1 - f
            FillSpan(TargetBuffer, y, y + 1, px0, px1, ra * nf + rb * f, ga * nf + gb * f, ba * nf + bb * f,
                aa * nf + ab * f)
        end
    else
        local inv = 1 / (x1 - x0)
        local len = (px1 - px0) * 4
        local opaque = aa >= 255 and ab >= 255
        local prev_o = 0
        for y = py0, py1 - 1 do
            local o = (y * TargetWidth + px0) * 4 + TargetBase
            if y > py0 and (opaque or RowRepeats(o, len, true))
                or (y == py0 and not opaque and RowRepeats(o, len, false)) then
                buffer.copy(TargetBuffer, o, TargetBuffer, prev_o, len)
            else
                local oo = o
                for x = px0, px1 - 1 do
                    local f = (x + 0.5 - x0) * inv
                    local nf = 1 - f
                    BlendPixel(TargetBuffer, oo, ra * nf + rb * f, ga * nf + gb * f, ba * nf + bb * f, aa * nf + ab * f)
                    oo = oo + 4
                end
            end
            prev_o = o
        end
    end
end

-- x0 y0: target pixel stored at buf's byte 0 (a sub-rectangle target: width = its width)
function M.SetTarget(buf: buffer, width: number, x0: number?, y0: number?)
    TargetBuffer, TargetWidth, TargetBase = buf, width, -((y0 or 0) * width + (x0 or 0)) * 4
    for y = RowLo, RowHi - 1 do RowX1[y] = RowX0[y] end
    RowLo, RowHi = 0, 0
end

@native
function M.ClearRect(rx0: number, ry0: number, rx1: number, ry1: number)
    local rw = rx1 - rx0
    for y = RowLo, RowHi - 1 do RowX1[y] = RowX0[y] end
    for y = ry0, ry1 - 1 do RowX0[y], RowX1[y], RowV[y] = rx0, rx1, 0 end
    RowLo, RowHi = ry0, ry1
    if rw == TargetWidth then
        buffer.fill(TargetBuffer, (ry0 * TargetWidth + rx0) * 4 + TargetBase, 0, (ry1 - ry0) * TargetWidth * 4)
    else
        for y = ry0, ry1 - 1 do buffer.fill(TargetBuffer, (y * TargetWidth + rx0) * 4 + TargetBase, 0, rw * 4) end
    end
end

-- kind: 0 triangle (va vb vc), 1 rect (TL va, BR vc), 2/3 gradient kind 1/2, 4 line quad (va vb vc vd)
@native
local function DrawPrim(kind: number, t, vbuf: buffer, va: number, vb: number, vc: number, vd: number, tox: number,
    toy: number, cx0: number, cy0: number, cx1: number, cy1: number)
    if kind == 0 then
        DrawTriangle(TargetBuffer, vbuf, va, vb, vc, t, cx0, cy0, cx1, cy1, tox, toy)
        return
    elseif kind == 4 then
        DrawLineQuad(TargetBuffer, vbuf, va, vb, vc, vd, t, cx0, cy0, cx1, cy1, tox, toy)
        return
    end
    local ax, ay, cx, cy = readf64(vbuf, va) - tox, readf64(vbuf, va + 8) - toy, readf64(vbuf, vc) - tox,
        readf64(vbuf, vc + 8) - toy
    if kind == 1 then
        DrawRect(TargetBuffer, ax, ay, cx, cy, readf64(vbuf, va + 16), readf64(vbuf, va + 24), readf64(vbuf, vc + 16),
            readf64(vbuf, vc + 24), readu32(vbuf, va + 32), t, cx0, cy0, cx1, cy1)
    else
        DrawRectGradient(TargetBuffer, ax, ay, cx, cy, readu32(vbuf, va + 32), readu32(vbuf, vc + 32), kind - 1, t,
            readf64(vbuf, va + 16), readf64(vbuf, va + 24), cx0, cy0, cx1, cy1)
    end
end
M.DrawPrim = DrawPrim

-- Packed tile jobs -> one exact-size buffer per rect (rasterized straight into it), in job order (worker + main-thread
-- fallback)
@native
function M.RasterJobs(P: buffer, T: buffer, tlen: number, textures): { buffer }
    local ClearRect, SetTarget = M.ClearRect, M.SetTarget
    local REC_A, REC_B, REC_C, REC_D = M.REC_A, M.REC_B, M.REC_C, M.REC_D
    local out, no = {}, 0
    local o = 0
    while o < tlen do
        local tox, toy = readf64(T, o), readf64(T, o + 8)
        local x0, y0, nr, count = readi32(T, o + 16), readi32(T, o + 20), readi32(T, o + 24), readi32(T, o + 28)
        local ro = o + 32
        local po = ro + nr * 16
        o = po + count * 4
        for r = 0, nr - 1 do
            local rx0, ry0, rx1, ry1 = readi32(T, ro + r * 16), readi32(T, ro + r * 16 + 4),
                readi32(T, ro + r * 16 + 8), readi32(T, ro + r * 16 + 12)
            local rw, rh = rx1 - rx0, ry1 - ry0
            local sub = buffer.create(rw * rh * 4)
            SetTarget(sub, rw, rx0, ry0)
            ClearRect(rx0, ry0, rx1, ry1)
            for k = 0, count - 1 do
                local q = readi32(T, po + k * 4)
                local cx0, cy0 = max(readi32(P, q + 8) - x0, rx0), max(readi32(P, q + 12) - y0, ry0)
                local cx1, cy1 = min(readi32(P, q + 16) - x0, rx1), min(readi32(P, q + 20) - y0, ry1)
                if cx0 >= cx1 or cy0 >= cy1 or readi32(P, q + 24) - x0 >= rx1 or readi32(P, q + 28) - y0 >= ry1
                    or readi32(P, q + 32) - x0 <= rx0 or readi32(P, q + 36) - y0 <= ry0 then
                    continue
                end
                local tid, t = readi32(P, q + 4), nil
                if tid >= 0 then t = textures[tid] end
                DrawPrim(readi32(P, q), t, P, q + REC_A, q + REC_B, q + REC_C, q + REC_D, tox, toy, cx0, cy0, cx1, cy1)
            end
            no += 1
            out[no] = sub
        end
    end
    return out
end

-- An Actor's texture copies (worker.luau; parallel.lua's Sync mode emulates it): drop the destroyed ids, apply the
-- updates parallel.lua's Flush sent. { id, buf, w, h, fill }: whole texture, rows past buf are all fill;
-- { id, false, w, h, offset, patch }: rows; { id, false, w, h, rects, patch }: x, y, w, h quadruples, rows packed.
function M.ApplyTextures(textures, updates, dropped)
    for _, id in dropped or {} do
        textures[id] = nil
    end
    for _, u in updates do
        if u[2] then
            local b, w, h, fill = u[2], u[3], u[4], u[5]
            local n, total = buffer.len(b), w * h * 4
            if n < total then
                local full = buffer.create(total)
                buffer.copy(full, 0, b)
                if fill ~= 0 then
                    buffer.writeu32(full, n, fill)
                    local k = 4
                    while k < total - n do
                        local c = math.min(k, total - n - k)
                        buffer.copy(full, n + k, full, n, c)
                        k += c
                    end
                end
                b = full
            end
            textures[u[1]] = { Buffer = b, Width = w, Height = h }
        elseif type(u[5]) == "table" then
            local t, rects, patch = textures[u[1]], u[5], u[6]
            local dst, w, o = t.Buffer, t.Width, 0
            for i = 1, #rects, 4 do
                local x, y, rw, rh = rects[i], rects[i + 1], rects[i + 2], rects[i + 3]
                for yy = y, y + rh - 1 do
                    buffer.copy(dst, (yy * w + x) * 4, patch, o, rw * 4)
                    o += rw * 4
                end
            end
        else
            buffer.copy(textures[u[1]].Buffer, u[5], u[6])
        end
    end
end

return M
