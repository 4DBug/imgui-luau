--- Dear ImGui
-- This is a Lua port of original `imstb_rectpack.h`

-- ALL TABLES IN THIS FILE ARE 1-BASED!
-- Avoids table creation when possible

-- [DEAR IMGUI]
-- This is a slightly modified version of stb_rect_pack.h 1.01.
-- Grep for [DEAR IMGUI] to find the changes.
--
-- stb_rect_pack.h - v1.01 - public domain - rectangle packing
-- Sean Barrett 2014
--
-- Useful for e.g. packing rectangular textures into an atlas.
-- Does not do rotation.
--
-- Not necessarily the awesomest packing method, but better than
-- the totally naive one in stb_truetype (which is primarily what
-- this is meant to replace).
--
-- Has only had a few tests run, may have issues.
--
-- More docs to come.
--
-- Uses table.sort and assert (STBRP_SORT and STBRP_ASSERT below).
--
-- This library currently uses the Skyline Bottom-Left algorithm.
--
-- Please note: better rectangle packers are welcome! Please
-- implement them to the same API, but with a different init
-- function.
--
-- Credits
--
--  Library
--    Sean Barrett
--  Minor features
--    Martins Mozeiko
--    github:IntellectualKitty
--
--  Bugfixes / warning fixes
--    Jeremy Jaussaud
--    Fabian Giesen
--
-- Version history:
--
--     1.01  (2021-07-11)  always use large rect mode, expose STBRP__MAXVAL in public section
--     1.00  (2019-02-25)  avoid small space waste; gracefully fail too-wide rectangles
--     0.99  (2019-02-07)  warning fixes
--     0.11  (2017-03-03)  return packing success/fail result
--     0.10  (2016-10-25)  remove cast-away-const to avoid warnings
--     0.09  (2016-08-27)  fix compiler warnings
--     0.08  (2015-09-13)  really fix bug with empty rects (w=0 or h=0)
--     0.07  (2015-09-13)  fix bug with empty rects (w=0 or h=0)
--     0.06  (2015-04-15)  added STBRP_SORT to allow replacing qsort
--     0.05:  added STBRP_ASSERT to allow replacing assert
--     0.04:  fixed minor bug in STBRP_LARGE_RECTS support
--     0.01:  initial release
--
-- LICENSE
--
--   See end of file for license information.

--- The `prev_link` can be stbrp_context or stbrp_node
--- @diagnostic disable

local bit32 = bit32

local STBRP_SORT = table.sort
local STBRP_ASSERT = assert
local STBRP__NOTUSED = function(_) end

-------------------------------------------------------------------------------
--
--       INCLUDE SECTION
--

local STBRP__MAXVAL = 0x7fffffff
-- Mostly for internal use, but this is the maximum supported coordinate value.

--- @enum STBRP_HEURISTIC_Skyline
local STBRP_HEURISTIC_Skyline = {
    default = 0,
    BL_sortHeight = 0,
    BF_sortHeight = 1
}

local STBRP__INIT_skyline = 1

--- @enum STBRP__PREV_LINK_TYPE
local STBRP__PREV_LINK_TYPE = {
    ACTIVE_HEAD = 0,
    NEXT = 1
}

--- @alias stbrp_coord int

--- @class stbrp_rect
--- @field id         int
--- @field w          stbrp_coord
--- @field h          stbrp_coord
--- @field x          stbrp_coord
--- @field y          stbrp_coord
--- @field was_packed int

--- @return stbrp_rect
--- @nodiscard
local function stbrp_rect()
    return {
        -- reserved for your use:
        id         = 0,

        -- input:
        w          = 0,
        h          = 0,

        -- output:
        x          = 0,
        y          = 0,
        was_packed = 0 -- non-zero if valid packing
    }
end

--- @class stbrp_node
--- @field x    stbrp_coord
--- @field y    stbrp_coord
--- @field next stbrp_node

--- @return stbrp_node
--- @nodiscard
local function stbrp_node()
    return {
        x    = 0,
        y    = 0,
        next = nil
    }
end

--- @class stbrp_context
--- @field width       int
--- @field height      int
--- @field align       int
--- @field init_mode   int
--- @field heuristic   int
--- @field num_nodes   int
--- @field active_head stbrp_node
--- @field free_head   stbrp_node
--- @field extra       stbrp_node[]

--- @return stbrp_context
--- @nodiscard
local function stbrp_context()
    return {
        width     = 0,
        height    = 0,
        align     = 0,
        init_mode = 0,
        heuristic = 0,
        num_nodes = 0,

        active_head = nil,
        free_head   = nil,
        extra       = {stbrp_node(), stbrp_node()} -- we allocate two extra nodes so optimal user-node-count is 'width' not 'width+2'
    }
end

--- @class stbrp__findresult
--- @field x               int
--- @field y               int
--- @field prev_link?      table
--- @field prev_link_type? int

--- @return stbrp__findresult
local function stbrp__findresult()
    return {
        x = 0,
        y = 0,

        prev_link      = nil,
        prev_link_type = nil
    }
end

-------------------------------------------------------------------------------
--
--     IMPLEMENTATION SECTION
--

-- Optionally select which packing heuristic the library should use. Different
-- heuristics will produce better/worse results for different data sets.
-- If you call init again, this will be reset to the default.
--- @param context   stbrp_context
--- @param heuristic int
local function stbrp_setup_heuristic(context, heuristic)
    if context.init_mode == STBRP__INIT_skyline then
        STBRP_ASSERT(heuristic == STBRP_HEURISTIC_Skyline.BL_sortHeight or heuristic == STBRP_HEURISTIC_Skyline.BF_sortHeight)
        context.heuristic = heuristic
    else
        STBRP_ASSERT(false)
    end
end

-- Optionally call this function after init but before doing any packing to
-- change the handling of the out-of-temp-memory scenario, described above.
-- If you call init again, this will be reset to the default (false).
--- @param context          stbrp_context
--- @param allow_out_of_mem boolean
local function stbrp_setup_allow_out_of_mem(context, allow_out_of_mem)
    if allow_out_of_mem then
        -- if it's ok to run out of memory, then don't bother aligning them;
        -- this gives better packing, but may fail due to OOM (even though
        -- the rectangles easily fit). @TODO a smarter approach would be to only
        -- quantize once we've hit OOM, then we could get rid of this parameter.
        context.align = 1
    else
        -- if it's not ok to run out of memory, then quantize the widths
        -- so that num_nodes is always enough nodes.
        --
        -- I.e. num_nodes * align >= width
        --                  align >= width / num_nodes
        --                  align = ceil(width/num_nodes)

        context.align = (context.width + context.num_nodes - 1) / context.num_nodes
    end
end

-- Initialize a rectangle packer to:
--    pack a rectangle that is 'width' by 'height' in dimensions
--    using temporary storage provided by the array 'nodes', which is 'num_nodes' long
--
-- You must call this function every time you start packing into a new target.
--
-- There is no "shutdown" function. The 'nodes' memory must stay valid for
-- the following stbrp_pack_rects() call (or calls), but can be freed after
-- the call (or calls) finish.
--
-- Note: to guarantee best results, either:
--       1. make sure 'num_nodes' >= 'width'
--   or  2. call stbrp_setup_allow_out_of_mem() defined above with 'allow_out_of_mem = true'
--
-- If you don't do either of the above things, widths will be quantized to multiples
-- of small integers to guarantee the algorithm doesn't run out of temporary storage.
--
-- If you do #2, then the non-quantized algorithm will be used, but the algorithm
-- may run out of temporary storage and be unable to pack some rectangles.
--- @param context   stbrp_context
--- @param width     int
--- @param height    int
--- @param nodes     stbrp_node[]
--- @param num_nodes int
function stbrp_init_target(context, width, height, nodes, num_nodes)
    for i = 1, num_nodes - 1 do
        nodes[i].next = nodes[i + 1]
    end
    nodes[num_nodes].next = nil
    context.init_mode = STBRP__INIT_skyline
    context.heuristic = STBRP_HEURISTIC_Skyline.default
    context.free_head = nodes[1]
    context.active_head = context.extra[1]
    context.width = width
    context.height = height
    context.num_nodes = num_nodes
    stbrp_setup_allow_out_of_mem(context, false)

    -- node 0 is the full width, node 1 is the sentinel (lets us not store width explicitly)
    context.extra[1].x = 0
    context.extra[1].y = 0
    context.extra[1].next = context.extra[2]
    context.extra[2].x = width
    context.extra[2].y = bit32.lshift(1, 30)
    context.extra[2].next = nil
end

-- find minimum y position if it starts at x1
-- Returns (min_y, waste_area)
--- @param c stbrp_context
--- @param first stbrp_node
--- @param x0 int
--- @param width int
--- @return int, int
local function stbrp__skyline_find_min_y(c, first, x0, width)
    local node = first
    local x1 = x0 + width

    STBRP__NOTUSED(c)

    STBRP_ASSERT(first.x <= x0)

    STBRP_ASSERT(node.next.x > x0) -- we ended up handling this in the caller for efficiency

    STBRP_ASSERT(node.x <= x0)

    local min_y = 0
    local waste_area = 0
    local visited_width = 0
    while node.x < x1 do
        if node.y > min_y then
            -- raise min_y higher.
            -- we've accounted for all waste up to min_y,
            -- but we'll now add more waste for everything we've visited
            waste_area = waste_area + visited_width * (node.y - min_y)
            min_y = node.y
            -- the first time through, visited_width might be reduced
            if node.x < x0 then
                visited_width = visited_width + node.next.x - x0
            else
                visited_width = visited_width + node.next.x - node.x
            end
        else
            -- add waste area
            local under_width = node.next.x - node.x
            if under_width + visited_width > width then
                under_width = width - visited_width
            end
            waste_area = waste_area + under_width * (min_y - node.y)
            visited_width = visited_width + under_width
        end
        node = node.next
    end

    return min_y, waste_area
end

--- @param c      stbrp_context
--- @param width  int
--- @param height int
--- @return stbrp__findresult
local function stbrp__skyline_find_best_pos(c, width, height)
    local best_waste = bit32.lshift(1, 30)
    local best_x = 0
    local best_y = bit32.lshift(1, 30)
    local fr = stbrp__findresult()
    local best_prev_link = nil
    local best_prev_link_type = nil

    -- align to multiple of c.align
    width = width + c.align - 1
    width = width - width % c.align
    STBRP_ASSERT(width % c.align == 0)

    -- if it can't possibly fit, bail immediately
    if width > c.width or height > c.height then
        fr.prev_link = nil
        fr.prev_link_type = nil
        fr.x = 0
        fr.y = 0
        return fr
    end

    local prev_link = c
    local prev_link_type = STBRP__PREV_LINK_TYPE.ACTIVE_HEAD
    local node = c.active_head

    while (node.x + width <= c.width) do
        local y, waste = stbrp__skyline_find_min_y(c, node, node.x, width)

        if c.heuristic == STBRP_HEURISTIC_Skyline.BL_sortHeight then -- actually just want to test BL
            -- bottom left
            if y < best_y then
                best_y = y
                best_prev_link = prev_link
                best_prev_link_type = prev_link_type
                best_x = node.x
            end
        else
            -- best-fit
            if y + height <= c.height then
                -- can only use it if it first vertically
                if y < best_y or (y == best_y and waste < best_waste) then
                    best_y = y
                    best_waste = waste
                    best_prev_link = prev_link
                    best_prev_link_type = prev_link_type
                    best_x = node.x
                end
            end
        end

        prev_link = node
        prev_link_type = STBRP__PREV_LINK_TYPE.NEXT
        node = node.next
    end

    -- if doing best-fit (BF), we also have to try aligning right edge to each node position
    --
    -- e.g, if fitting
    --
    --     ____________________
    --    |____________________|
    --
    --            into
    --
    --   |                         |
    --   |             ____________|
    --   |____________|
    --
    -- then right-aligned reduces waste, but bottom-left BL is always chooses left-aligned
    --
    -- This makes BF take about 2x the time

    if c.heuristic == STBRP_HEURISTIC_Skyline.BF_sortHeight then
        local tail = c.active_head
        local node_scan = c.active_head
        local prev_link_scan = c
        local prev_link_scan_type = STBRP__PREV_LINK_TYPE.ACTIVE_HEAD

        -- find first node that's admissible
        while tail and tail.x < width do
            tail = tail.next
        end

        while tail do
            local xpos = tail.x - width
            STBRP_ASSERT(xpos >= 0)

            -- find the left position that matches this
            while node_scan.next and node_scan.next.x <= xpos do
                prev_link_scan = node_scan
                prev_link_scan_type = STBRP__PREV_LINK_TYPE.NEXT
                node_scan = node_scan.next
            end

            if node_scan then
                STBRP_ASSERT(node_scan.next.x > xpos and node_scan.x <= xpos)

                local y, waste = stbrp__skyline_find_min_y(c, node_scan, xpos, width)

                if y + height <= c.height then
                    if y <= best_y then
                        if y < best_y or waste < best_waste or (waste == best_waste and xpos < best_x) then
                            best_x = xpos
                            -- STBRP_ASSERT(y <= best_y); [DEAR IMGUI]
                            best_y = y
                            best_waste = waste
                            best_prev_link = prev_link_scan
                            best_prev_link_type = prev_link_scan_type
                        end
                    end
                end
            end

            tail = tail.next
        end
    end

    fr.prev_link = best_prev_link
    fr.prev_link_type = best_prev_link_type
    fr.x = best_x
    fr.y = best_y
    return fr
end

--- @param context stbrp_context
--- @param width   int
--- @param height  int
--- @return stbrp__findresult
local function stbrp__skyline_pack_rectangle(context, width, height)
    -- find best position according to heuristic
    local res = stbrp__skyline_find_best_pos(context, width, height)

    -- bail if:
    --    1. it failed
    --    2. the best node doesn't fit (we don't always check this)
    --    3. we're out of memory
    if res.prev_link == nil or res.y + height > context.height or context.free_head == nil then
        res.prev_link = nil
        res.prev_link_type = nil
        return res
    end

    -- on success, create new node
    local node = context.free_head
    node.x = res.x
    node.y = res.y + height
    context.free_head = node.next

    -- insert the new node into the right starting point, and
    -- let 'cur' point to the remaining nodes needing to be
    -- stitched back in

    local cur
    if res.prev_link_type == STBRP__PREV_LINK_TYPE.ACTIVE_HEAD then
        cur = res.prev_link.active_head
    else
        cur = res.prev_link.next
    end

    if cur.x < res.x then
        -- preserve the existing one, so start testing with the next one
        local next = cur.next
        cur.next = node
        cur = next
    else
        if res.prev_link_type == STBRP__PREV_LINK_TYPE.ACTIVE_HEAD then
            res.prev_link.active_head = node
        else
            res.prev_link.next = node
        end
    end

    -- from here, traverse cur and free the nodes, until we get to one
    -- that shouldn't be freed
    while cur.next and cur.next.x <= res.x + width do
        local next = cur.next
        -- move the current node to the free list
        cur.next = context.free_head
        context.free_head = cur
        cur = next
    end

    -- stitch the list back in
    node.next = cur

    if cur.x < res.x + width then
        cur.x = res.x + width
    end

    return res
end

--- @param a stbrp_rect
--- @param b stbrp_rect
--- @return bool
--- @package
local function rect_height_compare(a, b)
    if a.h > b.h then
        return true
    elseif a.h < b.h then
        return false
    else
        return a.w > b.w
    end
end

--- @param a stbrp_rect
--- @param b stbrp_rect
--- @return bool
--- @package
local function rect_original_order(a, b)
    return a.was_packed < b.was_packed
end

-- Assign packed locations to rectangles. The rectangles are of type
-- 'stbrp_rect' defined above, stored in the array 'rects', and there
-- are 'num_rects' many of them.
--
-- Rectangles which are successfully packed have the 'was_packed' flag
-- set to a non-zero value and 'x' and 'y' store the minimum location
-- on each axis (i.e. bottom-left in cartesian coordinates, top-left
-- if you imagine y increasing downwards). Rectangles which do not fit
-- have the 'was_packed' flag set to 0.
--
-- You should not try to access the 'rects' array from another thread
-- while this function is running, as the function temporarily reorders
-- the array while it executes.
--
-- To pack into another rectangle, you need to call stbrp_init_target
-- again. To continue packing into the same rectangle, you can call
-- this function again. Calling this multiple times with multiple rect
-- arrays will probably produce worse packing results than calling it
-- a single time with the full rectangle array, but the option is
-- available.
--
-- The function returns 1 if all of the rectangles were successfully
-- packed and 0 otherwise.
--- @param context   stbrp_context
--- @param rects     stbrp_rect[]
--- @param num_rects int
--- @return int
local function stbrp_pack_rects(context, rects, num_rects)
    local all_rects_packed = 1

    -- we use the 'was_packed' field internally to allow sorting/unsorting
    for i = 1, num_rects do
        rects[i].was_packed = (i - 1)
    end

    -- sort according to heuristic
    STBRP_SORT(rects, rect_height_compare)

    for i = 1, num_rects do
        if rects[i].w == 0 or rects[i].h == 0 then
            rects[i].x = 0 -- empty rect needs no space
            rects[i].y = 0
        else
            local fr = stbrp__skyline_pack_rectangle(context, rects[i].w, rects[i].h)
            if fr.prev_link then
                rects[i].x = fr.x
                rects[i].y = fr.y
            else
                rects[i].x = STBRP__MAXVAL
                rects[i].y = STBRP__MAXVAL
            end
        end
    end

    -- unsort
    STBRP_SORT(rects, rect_original_order)

    -- set was_packed flags and all_rects_packed status
    for i = 1, num_rects do
        rects[i].was_packed = (rects[i].x == STBRP__MAXVAL and rects[i].y == STBRP__MAXVAL) and 0 or 1
        if rects[i].was_packed == 0 then
            all_rects_packed = 0
        end
    end

    -- return the all_rects_packed status
    return all_rects_packed
end

return {
    context = stbrp_context,
    rect    = stbrp_rect,
    node    = stbrp_node,

    pack_rects             = stbrp_pack_rects,
    init_target            = stbrp_init_target,
    setup_allow_out_of_mem = stbrp_setup_allow_out_of_mem,
    setup_heuristic        = stbrp_setup_heuristic
}

-- ------------------------------------------------------------------------------
-- This software is available under 2 licenses -- choose whichever you prefer.
-- ------------------------------------------------------------------------------
-- ALTERNATIVE A - MIT License
-- Copyright (c) 2017 Sean Barrett
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- ------------------------------------------------------------------------------
-- ALTERNATIVE B - Public Domain (www.unlicense.org)
-- This is free and unencumbered software released into the public domain.
-- Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
-- software, either in source code form or as a compiled binary, for any purpose,
-- commercial or non-commercial, and by any means.
-- In jurisdictions that recognize copyright laws, the author or authors of this
-- software dedicate any and all copyright interest in the software to the public
-- domain. We make this dedication for the benefit of the public at large and to
-- the detriment of our heirs and successors. We intend this dedication to be an
-- overt act of relinquishment in perpetuity of all present and future rights to
-- this software under copyright law.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
-- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-- ------------------------------------------------------------------------------
