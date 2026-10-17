--- Dear ImGui
-- [Port] This is a minimal Lua impl of C-like sscanf, sprintf sub-set

-- [Port] Supports:
-- - %x, %X, %nx, %nX (where n is a number)
-- - %d, %nd, %u, %nu (where n is a number)
-- - length modifiers h, hh, l, ll, I64 on integers: ll/I64 = 64-bit range (doubles: exact only within +-2^53)
-- - %f, %lf (very limited)
--
-- [Port] Returns items_matched instead of EOF on error

local _byte = string.byte

local CHAR_PERCENT = _byte'%'
local CHAR_DOT = _byte'.'
local CHAR_PLUS, CHAR_MINUS = _byte'+', _byte'-'
local CHAR_0, CHAR_9 = _byte'0', _byte'9'
local CHAR_a, CHAR_A = _byte'a', _byte'A'
local CHAR_d = _byte'd'
local CHAR_l = _byte'l'
local CHAR_h = _byte'h'
local CHAR_u = _byte'u'
local CHAR_I = _byte'I'
local CHAR_f, CHAR_F = _byte'f', _byte'F'
local CHAR_x, CHAR_X = _byte'x', _byte'X'

local function isspace(c) return c == 32 or c == 9 end
local function isdigit(c) return c >= CHAR_0 and c <= CHAR_9 end
local function isxdigit(c) return isdigit(c) or (c >= CHAR_a and c <= CHAR_f) or (c >= CHAR_A and c <= CHAR_F) end

local function isdigit_under_base(c, base)
    if     base == 10 then return isdigit(c)
    elseif base == 16 then return isxdigit(c)
    end
end

local function hex_digit_to_int(c)
    if c >= CHAR_0 and c <= CHAR_9 then return c - CHAR_0 end
    if c >= CHAR_a and c <= CHAR_f then return c - CHAR_a + 10 end
    if c >= CHAR_A and c <= CHAR_F then return c - CHAR_A + 10 end
end

-- [Port] we force this behavior by default
local function clamp_if_overflow(spec, val, is_64)
    if spec == CHAR_d or spec == CHAR_x or spec == CHAR_X then
        local max = is_64 and 9223372036854775807 or INT_MAX
        local min = is_64 and -9223372036854775808 or INT_MIN
        if val > max then return max end
        if val < min then return min end
    elseif spec == CHAR_u then
        local max = is_64 and 18446744073709551615 or UINT_MAX
        if val > max then return max end
    end

    return val
end

--- @param buffer       char[]
--- @param buffer_begin int
--- @param format       string
--- @param result       table  # table to store parsed values
local function sscanf(buffer, buffer_begin, format, result)
    local p = buffer_begin
    local f = 1 -- [Port] format_begin
    local format_len = #format
    local assigned = 0
    local items_matched = 0

    while f <= format_len do
        repeat
        if isspace(_byte(format, f, f)) then
            while isspace(buffer[p]) do
                p = p + 1
            end
            f = f + 1

            break
        end

        if _byte(format, f, f) ~= CHAR_PERCENT then
            if buffer[p] == _byte(format, f, f) then
                p = p + 1
                f = f + 1
            else
                return items_matched
            end

            break
        end

        -- [Port] encountered % in fmt
        f = f + 1

        -- [Port] %%
        if _byte(format, f, f) == CHAR_PERCENT then
            if buffer[p] == CHAR_PERCENT then
                p = p + 1
                f = f + 1
            else
                return items_matched
            end

            break
        end

        -- [Port] handle optional width
        local width = 0
        while isdigit(_byte(format, f, f)) do
            width = width * 10 + _byte(format, f, f) - CHAR_0
            f = f + 1
        end
        if width == 0 then
            width = math.huge
        end

        -- [Port] length modifiers
        local n_l = 0
        while _byte(format, f, f) == CHAR_l or _byte(format, f, f) == CHAR_h do
            if _byte(format, f, f) == CHAR_l then n_l = n_l + 1 end
            f = f + 1
        end
        if _byte(format, f, f) == CHAR_I and string.sub(format, f, f + 2) == "I64" then
            n_l = 2
            f = f + 3
        end
        local is_64 = n_l >= 2

        local spec = _byte(format, f, f)
        local base
        local is_float = false
        if     spec == CHAR_x or spec == CHAR_X then
            base = 16
        elseif spec == CHAR_d or spec == CHAR_u then
            base = 10
        elseif spec == CHAR_f or spec == CHAR_F then
            is_float = true -- [Port] TODO: distinguish %lf from %f?
        else
            return items_matched
        end
        f = f + 1

        while isspace(buffer[p]) do
            p = p + 1
        end

        local val
        if is_float then
            local sign = 1
            if     buffer[p] == CHAR_PLUS then
                p = p + 1
            elseif buffer[p] == CHAR_MINUS then
                sign = -1
                p = p + 1
            end

            -- [Port] inf, nan are not handled

            local p_start = p
            local int_part = 0

            while isdigit(buffer[p]) do
                int_part = int_part * 10 + (buffer[p] - CHAR_0)
                p = p + 1
            end

            local frac_part = 0
            local frac_div = 1
            if buffer[p] == CHAR_DOT then
                p = p + 1
                while isdigit(buffer[p]) do
                    frac_part = frac_part * 10 + (buffer[p] - CHAR_0)
                    frac_div = frac_div * 10
                    p = p + 1
                end
            end

            if p == p_start then
                return items_matched
            end

            val = sign * (int_part + frac_part / frac_div)
        else
            local sign = 1
            -- [Port] optional sign
            if base == 10 then
                if     buffer[p] == CHAR_PLUS then
                    p = p + 1
                    width = width - 1
                elseif buffer[p] == CHAR_MINUS then
                    sign = -1
                    p = p + 1
                    width = width - 1
                end
            end

            local p_start = p
            while width > 0 and buffer[p] and isdigit_under_base(buffer[p], base) do
                p = p + 1
                width = width - 1
            end

            if p == p_start then
                return items_matched
            end

            val = 0
            while p_start < p do
                local c = buffer[p_start]
                p_start = p_start + 1
                val = val * base + sign * hex_digit_to_int(c)

                local old_val = val
                val = clamp_if_overflow(spec, val, is_64)
                if old_val ~= val then
                    break
                end
            end
            if spec == CHAR_u and val < 0 then
                val = val + (is_64 and 18446744073709551616 or 4294967296) -- [Port] unsigned wrap-around like strtoul()
            end
        end

        result[assigned + 1] = val
        assigned = assigned + 1
        items_matched = items_matched + 1

        until true
    end

    return items_matched
end

local function sprintf()

end

return sscanf