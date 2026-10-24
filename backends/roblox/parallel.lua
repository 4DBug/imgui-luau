-- Parallel executor (opt-in, EnableParallel): Tile packs each dirty tile per Actor, Flush sends the batch while the
-- dispatch window (PreAnimation .. Finish) is open, else rasterizes it at once; Finish uploads every result.
local Raster = IM_INCLUDE("roblox/raster.lua")
local Textures = IM_INCLUDE("roblox/textures.lua")
local Render = IM_INCLUDE("roblox/render.lua")

local Players = game:GetService("Players")
local EditableImages, Records = Textures.EditableImages, Textures.Records
local PrimA, PrimB, PrimC, PrimD, PrimGradient = Render.PrimA, Render.PrimB, Render.PrimC, Render.PrimD,
    Render.PrimGradient
local PrimCmd, CmdTexture, CmdTexId, CmdVtxBuffer = Render.PrimCmd, Render.CmdTexture, Render.CmdTexId,
    Render.CmdVtxBuffer
local CmdClipX0, CmdClipY0, CmdClipX1, CmdClipY1 = Render.CmdClipX0, Render.CmdClipY0, Render.CmdClipX1,
    Render.CmdClipY1
local PrimBoundsX0, PrimBoundsY0, PrimBoundsX1, PrimBoundsY1 = Render.PrimBoundsX0, Render.PrimBoundsY0,
    Render.PrimBoundsX1, Render.PrimBoundsY1

local M = Render.Parallel
local writei32, writef64, copy = buffer.writei32, buffer.writef64, buffer.copy
local RasterJobs = Raster.RasterJobs
local VTX, REC, REC_A, REC_B, REC_C, REC_D, JOB = Raster.VTX, Raster.REC, Raster.REC_A, Raster.REC_B, Raster.REC_C,
    Raster.REC_D, Raster.JOB
assert(VTX == VTX_STRIDE, "raster.lua: vertex layout differs from ImDrawVert")

-- Sync / SyncDrop / Inline: test hooks (inline "workers"; drop half their results; bypass the executor)
M.Config = { Actors = 4, MinTiles = 1, MinPixels = 2048, MaxBytesPerPixel = 0, Sync = false, SyncDrop = false,
    Inline = false, Worker = nil }
M.Stats = {
    ParallelFlushes = 0, SerialFlushes = 0, Tiles = 0, Fallbacks = 0, Late = 0, Pack = 0, Flush = 0, Finish = 0,
    SendBytes = 0, TexSends = 0, TexBytes = 0, Rects = 0, Recv = 0, RecvBytes = 0,
    -- why a flush stayed serial: dispatch window closed / Actors not ready / below MinTiles or MinPixels / over MaxBytesPerPixel
    SerialClosed = 0, SerialNotReady = 0, SerialSmall = 0, SerialBytes = 0,
}
local Stats = M.Stats

local NA = 1
local Pb, Pn, Tb, Tn, load, used = {}, {}, {}, {}, {}, {}
local stamp, poff, stamp_base = {}, {}, 0
local free_batches, free_bufs, free_bytes = {}, {}, 0
local function newBatch()
    return table.remove(free_batches)
        or { N = 0, Px = 0, Img = {}, Actor = {}, NR = {}, Rect = {}, P = {}, T = {}, TL = {}, Res = {} }
end
local function takeBuf(len: number): buffer
    local l = free_bufs[len]
    local b = l and table.remove(l)
    if b then
        free_bytes -= len
        return b
    end
    return buffer.create(len)
end
local function giveBuf(b: buffer)
    local len = buffer.len(b)
    local l = free_bufs[len]
    if not l then
        l = {}
        free_bufs[len] = l
    end
    if #l < 8 and free_bytes + len <= 4194304 then
        l[#l + 1] = b
        free_bytes += len
    end
end
local jobs = newBatch()
local NO_TEX = {}
local cur = {}
local pending, by_id, batch_no = {}, {}, 0
local open = false
local actors, ready, conns, folder = {}, false, {}, nil
local sent = {}
-- ids of destroyed textures each Actor holds a copy of, sent with its next job (the Actor drops them)
local drops = {}
local NO_DROPS = {}
local sync_tex = {} -- Sync mode: the "Actors'" texture copies
EditableImages.TextureDropped = function(id, rec)
    if not rec then
        return
    end
    for a = 1, NA do
        local s = sent[a]
        if s and s[rec] ~= nil then
            s[rec] = nil
            local d = drops[a]
            d[#d + 1] = id
        end
    end
end

local function grow(b: buffer, need: number): buffer
    local n = buffer.len(b)
    if need <= n then
        return b
    end
    while n < need do
        n *= 2
    end
    local nb = buffer.create(n)
    copy(nb, 0, b)
    return nb
end

local function reset()
    for a = 1, NA do
        Pn[a], Tn[a], load[a] = 0, 0, 0
        if used[a] then
            table.clear(used[a])
        end
    end
    stamp_base += 64
    jobs = newBatch()
end

-- One dirty tile (rects in EditableImages.DX0..DY1[1..nr], primitives list[1..count]) -> the least loaded Actor
@native
function M.Tile(img, list, count: number, x0: number, y0: number, tox: number, toy: number, nr: number)
    local t0 = os.clock()
    local DX0, DY0, DX1, DY1 = EditableImages.DX0, EditableImages.DY0, EditableImages.DX1, EditableImages.DY1
    local area = 0
    for r = 1, nr do
        area += (DX1[r] - DX0[r]) * (DY1[r] - DY0[r])
    end
    local a = 1
    for i = 2, NA do
        if load[i] < load[a] then
            a = i
        end
    end
    load[a] += area + 200
    jobs.Px += area
    local j = jobs.N + 1
    jobs.N = j
    jobs.Img[j], jobs.Actor[j], jobs.NR[j] = img, a, nr
    Stats.Rects += nr
    local R = jobs.Rect
    local ri = #R
    for r = 1, nr do
        R[ri + 1], R[ri + 2], R[ri + 3], R[ri + 4] = DX0[r], DY0[r], DX1[r], DY1[r]
        ri += 4
    end

    local T, to = grow(Tb[a], Tn[a] + JOB + nr * 16 + count * 4), Tn[a]
    Tb[a] = T
    writef64(T, to, tox)
    writef64(T, to + 8, toy)
    writei32(T, to + 16, x0)
    writei32(T, to + 20, y0)
    writei32(T, to + 24, nr)
    writei32(T, to + 28, count)
    to += JOB
    for r = 1, nr do
        writei32(T, to, DX0[r])
        writei32(T, to + 4, DY0[r])
        writei32(T, to + 8, DX1[r])
        writei32(T, to + 12, DY1[r])
        to += 16
    end
    local P, pn = grow(Pb[a], Pn[a] + count * REC), Pn[a]
    Pb[a] = P
    local st = stamp_base + a
    local u = used[a]
    for k = 1, count do
        local p = list[k]
        if stamp[p] ~= st then
            stamp[p], poff[p] = st, pn
            local cmd = PrimCmd[p]
            local d, t = PrimD[p], CmdTexture[cmd]
            local gk = PrimGradient[p]
            writei32(P, pn, d and (gk and gk + 1 or 1) or 0)
            writei32(P, pn + 4, t and CmdTexId[cmd] or -1)
            if t then
                u[t] = CmdTexId[cmd]
            end
            writei32(P, pn + 8, CmdClipX0[cmd])
            writei32(P, pn + 12, CmdClipY0[cmd])
            writei32(P, pn + 16, CmdClipX1[cmd])
            writei32(P, pn + 20, CmdClipY1[cmd])
            writei32(P, pn + 24, PrimBoundsX0[p])
            writei32(P, pn + 28, PrimBoundsY0[p])
            writei32(P, pn + 32, PrimBoundsX1[p])
            writei32(P, pn + 36, PrimBoundsY1[p])
            local vb = CmdVtxBuffer[cmd]
            copy(P, pn + REC_A, vb, PrimA[p], VTX)
            copy(P, pn + REC_C, vb, PrimC[p], VTX)
            if not d or gk == 3 or gk == 4 then
                copy(P, pn + REC_B, vb, PrimB[p], VTX)
            end
            if gk == 3 or gk == 4 then copy(P, pn + REC_D, vb, d, VTX) end
            pn += REC
        end
        writei32(T, to, poff[p])
        to += 4
    end
    Pn[a], Tn[a] = pn, to
    Stats.Pack += os.clock() - t0
end

local function upload(b)
    local alive, R, ri = EditableImages.ImageBytes, b.Rect, 0
    table.clear(cur)
    for j = 1, b.N do
        local a = b.Actor[j]
        local outs, c = b.Res[a], cur[a] or 0
        local img = b.Img[j]
        for _ = 1, b.NR[j] do
            c += 1
            if alive[img] then
                local x0, y0 = R[ri + 1], R[ri + 2]
                img:WritePixelsBuffer(Vector2.new(x0, y0), Vector2.new(R[ri + 3] - x0, R[ri + 4] - y0), outs[c])
            end
            ri += 4
        end
        cur[a] = c
    end
end

-- Uploads every pending batch (late worker results rasterized here) and closes the dispatch window
function M.Finish()
    open = false
    if #pending == 0 then
        return
    end
    local t0 = os.clock()
    for _, b in pending do
        for a = 1, NA do
            if b.TL[a] > 0 and not b.Res[a] then
                b.Res[a] = RasterJobs(b.P[a], b.T[a], b.TL[a], Records)
                if b.Sent then
                    Stats.Fallbacks += 1
                end
            end
        end
        upload(b)
        by_id[b.Id] = nil
        for a = 1, NA do
            if b.P[a] then
                giveBuf(b.P[a])
                giveBuf(b.T[a])
            end
        end
        b.N, b.Px, b.Sent = 0, 0, false
        table.clear(b.Img)
        table.clear(b.Actor)
        table.clear(b.NR)
        table.clear(b.Rect)
        table.clear(b.P)
        table.clear(b.T)
        table.clear(b.TL)
        table.clear(b.Res)
        if #free_batches < 8 then
            free_batches[#free_batches + 1] = b
        end
    end
    table.clear(pending)
    Stats.Finish += os.clock() - t0
end

-- A whole texture for an Actor without a copy (new id: grow/repack): only the rows above FillRow, the Actor fills the
-- rest with Fill (a new atlas is mostly empty). Built once per version, shared by every Actor's SendMessage.
local function fullCopy(rec, v: number): buffer
    if rec.HeadV ~= v then
        local src, len = rec.Buffer, (rec.FillRow or rec.Height) * rec.Width * 4
        local head = src
        if len < buffer.len(src) then
            head = buffer.create(len)
            copy(head, 0, src, 0, len)
        end
        rec.Head, rec.HeadV = head, v
    end
    return rec.Head
end

-- The pixels changed between versions had and v (rows y0..y1 of rec): the updated rects (rect list -> worker copies
-- each rect's rows), or the whole rows when they are smaller. Built once per (had, v), shared by every Actor.
local function patchCopy(rec, had: number, v: number, y0: number, y1: number): (buffer, any)
    if rec.PatchHad == had and rec.PatchV == v then
        return rec.Patch, rec.PatchAt
    end
    local row, src = rec.Width * 4, rec.Buffer
    local log, area = rec.Log, 0
    for k = had + 1, v do
        local r = log[k][3]
        if r then
            for i = 1, #r, 4 do area += r[i + 2] * r[i + 3] end
        end
    end
    local patch, at
    if area * 4 < (y1 - y0) * row then
        patch, at = buffer.create(area * 4), {}
        local o, n = 0, 0
        for k = had + 1, v do
            local r = log[k][3]
            if r then
                for i = 1, #r, 4 do
                    local x, y, w, h = r[i], r[i + 1], r[i + 2], r[i + 3]
                    at[n + 1], at[n + 2], at[n + 3], at[n + 4] = x, y, w, h
                    n += 4
                    for yy = y, y + h - 1 do
                        copy(patch, o, src, (yy * rec.Width + x) * 4, w * 4)
                        o += w * 4
                    end
                end
            end
        end
    else
        patch, at = buffer.create((y1 - y0) * row), y0 * row
        copy(patch, 0, src, y0 * row, (y1 - y0) * row)
    end
    rec.PatchHad, rec.PatchV, rec.Patch, rec.PatchAt = had, v, patch, at
    return patch, at
end

function M.Flush()
    local n = jobs.N
    if n == 0 then
        if not open then
            M.Finish()
        end
        return
    end
    local t0 = os.clock()
    local cfg = M.Config
    local par = open and (cfg.Sync or ready) and n >= cfg.MinTiles and jobs.Px >= cfg.MinPixels
    if par and cfg.MaxBytesPerPixel > 0 then
        local bytes = 0
        for a = 1, NA do
            bytes += Pn[a] + Tn[a]
        end
        par = bytes <= cfg.MaxBytesPerPixel * jobs.Px
        if not par then Stats.SerialBytes += 1 end
    elseif not par then
        if not open then Stats.SerialClosed += 1
        elseif not (cfg.Sync or ready) then Stats.SerialNotReady += 1
        else Stats.SerialSmall += 1 end
    end
    batch_no += 1
    local b = jobs
    b.Id, b.Sent = batch_no, par
    for a = 1, NA do
        local tl = Tn[a]
        b.TL[a] = tl
        if tl == 0 then
            continue
        end
        if not par then
            b.Res[a] = RasterJobs(Pb[a], Tb[a], tl, Records)
            continue
        end
        -- recycled copies rounded up to 4 KB (SendMessage copies the whole buffer)
        local P, T = takeBuf(Pn[a] + 4095 - (Pn[a] + 4095) % 4096), takeBuf(tl + 4095 - (tl + 4095) % 4096)
        copy(P, 0, Pb[a], 0, Pn[a])
        copy(T, 0, Tb[a], 0, tl)
        b.P[a], b.T[a] = P, T

        local tex, s = NO_TEX, sent[a]
        for rec, id in used[a] do
            local v = rec.V or 0
            local had = s[rec]
            if had ~= v then
                if tex == NO_TEX then
                    tex = {}
                end
                s[rec] = v
                -- the Actor has version `had`: send only the rows changed since then when the log covers them
                local y0, y1, log = math.huge, -1, rec.Log
                if had and log then
                    for k = had + 1, v do
                        local e = log[k]
                        if not e then y0 = nil; break end
                        if e[2] > e[1] then
                            if e[1] < y0 then y0 = e[1] end
                            if e[2] > y1 then y1 = e[2] end
                        end
                    end
                else
                    y0 = nil
                end
                if y0 == nil then
                    local buf = fullCopy(rec, v)
                    tex[#tex + 1] = { id, buf, rec.Width, rec.Height, rec.Fill or 0 }
                    Stats.TexBytes += buffer.len(buf)
                elseif y1 > y0 then
                    local patch, at = patchCopy(rec, had, v, y0, y1)
                    tex[#tex + 1] = { id, false, rec.Width, rec.Height, at, patch }
                    Stats.TexBytes += buffer.len(patch)
                end
                Stats.TexSends += 1
            end
        end
        Stats.SendBytes += Pn[a] + tl
        local d = drops[a]
        if #d > 0 then
            drops[a] = {}
        else
            d = NO_DROPS
        end
        if cfg.Sync then
            -- like an Actor: own texture copies, kept by the same messages (SendMessage copies: clone the buffers)
            local st = sync_tex[a]
            if not st then
                st = {}
                sync_tex[a] = st
            end
            local msg = table.create(#tex)
            for i, u in tex do
                local c = table.clone(u)
                for k, x in c do
                    if type(x) == "buffer" then
                        local nb = buffer.create(buffer.len(x))
                        copy(nb, 0, x)
                        c[k] = nb
                    end
                end
                msg[i] = c
            end
            Raster.ApplyTextures(st, msg, d)
            if not (cfg.SyncDrop and a % 2 == 0) then
                b.Res[a] = RasterJobs(P, T, tl, st)
            end
        else
            actors[a]:SendMessage("job", batch_no, P, T, tex, tl, d)
        end
    end
    if par then
        Stats.ParallelFlushes += 1
    else
        Stats.SerialFlushes += 1
    end
    Stats.Tiles += n
    by_id[batch_no] = b
    pending[#pending + 1] = b
    reset()
    Stats.Flush += os.clock() - t0
    if not open then
        M.Finish()
    end
end

function M.BeginFrame()
    open = true
end

local function setActors(n)
    NA = n
    for a = 1, n do
        Pb[a] = Pb[a] or buffer.create(4096)
        Tb[a] = Tb[a] or buffer.create(1024)
        used[a] = used[a] or {}
        sent[a] = setmetatable({}, { __mode = "k" })
        drops[a] = {}
        sync_tex[a] = nil
    end
    reset()
end
setActors(1)

function M.Disable()
    M.Finish()
    for _, c in conns do
        c:Disconnect()
    end
    table.clear(conns)
    if folder then
        folder:Destroy()
        folder = nil
    end
    table.clear(actors)
    ready, open = false, false
    M.On, M.Active = false, false
end

function M.Enable(opts)
    M.Disable()
    for k, v in opts or {} do
        M.Config[k] = v
    end
    local cfg = M.Config
    setActors(math.max(1, cfg.Actors))
    M.On = true
    if cfg.Sync then
        return
    end
    local RunService = game:GetService("RunService")
    -- bundle: script is the library ModuleScript (e.g. ImGui.Impl under the typed module)
    local template = cfg.Worker or script:FindFirstChild("Worker")
        or (script.Parent and script.Parent:FindFirstChild("Worker"))
    assert(template, "ImGui_ImplRoblox.EnableParallel: no Worker LocalScript (build/ImGuiWorker.client.luau) as a"
        .. " child of the ImGui module; or pass { Worker = ... }")
    folder = Instance.new("Folder")
    folder.Name = "ImGuiRasterActors"
    for a = 1, NA do
        local actor = Instance.new("Actor")
        actor.Name = "Raster" .. a
        local done = Instance.new("BindableEvent")
        done.Name = "Done"
        done.Parent = actor
        table.insert(conns, done.Event:Connect(function(id, outs)
            local t0, b = os.clock(), by_id[id]
            if b then
                b.Res[a] = outs
            else
                Stats.Late += 1
            end
            for _, o in outs do
                Stats.RecvBytes += buffer.len(o)
            end
            Stats.Recv += os.clock() - t0
        end))
        local w = template:Clone()
        w.Parent = actor
        actor.Parent = folder
        actors[a] = actor
    end
    folder.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
    ready = false
    table.insert(conns, RunService.PreAnimation:Connect(function()
        if not ready then
            ready = true
            for _, act in actors do
                if not act:GetAttribute("Ready") then
                    ready = false
                end
            end
        end
        open = true
    end))
    table.insert(conns, RunService.PostSimulation:Connect(M.Finish))
end

return M
