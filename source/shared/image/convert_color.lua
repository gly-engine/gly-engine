local math = require('math')
local floor = math.floor

local function round(value)
    return floor(value + 0.5)
end

local function bw2rgba(c)
    if c ~= 0 then return 0x000000FF end
    return 0xFFFFFFFF
end

local function bw2rgb(c)
    if c ~= 0 then return 0x000000 end
    return 0xFFFFFF
end

--! @details
--! Chroma and luma are bytes, so every term of the conversion has only 256
--! outcomes and every sum lands in a narrow band. Precomputing them turns the
--! per pixel work into table lookups, with no multiply, no divide, no floor
--! and no call. Rounding each term apart costs at most 1 of 255 per channel.
--!
--! SHIFT moves the sum into the array part of the clamp, and it rides inside
--! another table of the same sum so that it costs nothing of its own. Full
--! range needs no luma table at all, as its luma is the byte itself.
--! @details
--! A range is only built when something asks for it, because a picture of two
--! hundred pixels a side already outnumbers the 256 entries of a table.
local SHIFT = 320
local CLAMP
local LUMA_LIMITED
local RED_V, GREEN_U, GREEN_V, BLUE_U
local RED_V_LIMITED, GREEN_U_LIMITED, GREEN_V_LIMITED, BLUE_U_LIMITED

local function build_clamp()
    if CLAMP then return end
    CLAMP = {}
    for at = -SHIFT, 700 do
        local value = at
        if value < 0 then
            value = 0
        elseif value > 255 then
            value = 255
        end
        CLAMP[at + SHIFT] = value
    end
end

local function build_full()
    if RED_V then return end
    build_clamp()
    RED_V, GREEN_U, GREEN_V, BLUE_U = {}, {}, {}, {}
    for at = 0, 255 do
        local signed = at - 128
        RED_V[at] = round(1436 * signed / 1024) + SHIFT
        GREEN_U[at] = SHIFT - round(352 * signed / 1024)
        GREEN_V[at] = round(731 * signed / 1024)
        BLUE_U[at] = round(1815 * signed / 1024) + SHIFT
    end
end

local function build_limited()
    if LUMA_LIMITED then return end
    build_clamp()
    LUMA_LIMITED = {}
    RED_V_LIMITED, GREEN_U_LIMITED, GREEN_V_LIMITED, BLUE_U_LIMITED = {}, {}, {}, {}
    for at = 0, 255 do
        local signed = at - 128
        LUMA_LIMITED[at] = floor((298 * (at - 16) + 128) / 256) + SHIFT
        RED_V_LIMITED[at] = round(409 * signed / 256)
        GREEN_U_LIMITED[at] = round(100 * signed / 256)
        GREEN_V_LIMITED[at] = round(208 * signed / 256)
        BLUE_U_LIMITED[at] = round(516 * signed / 256)
    end
end

local function yuv2rgb(y, u, v)
    return CLAMP[y + RED_V[v]],
        CLAMP[y + GREEN_U[u] - GREEN_V[v]],
        CLAMP[y + BLUE_U[u]]
end

local function yuv2rgb_limited(y, u, v)
    local base = LUMA_LIMITED[y]
    return CLAMP[base + RED_V_LIMITED[v]],
        CLAMP[base - GREEN_U_LIMITED[u] - GREEN_V_LIMITED[v]],
        CLAMP[base + BLUE_U_LIMITED[u]]
end

--! @details
--! Builds the tables of the wanted range on the first ask and hands back the
--! converter, which takes a luma byte and two chroma bytes where 128 is
--! neutral. Pick it once per picture, never per pixel.
--! @param limited studio range, as a y4m that does not say XCOLORRANGE=FULL
local function yuv_converter(limited)
    if limited then
        build_limited()
        return yuv2rgb_limited
    end
    build_full()
    return yuv2rgb
end

--! @todo return 4? how to encoder detect stride in?
local function rgba(r, g, b, a)
    local color = (r * 0xFFFFFF) + (g * 0xFFFF) + (b * 0xFF) + a
    return color, color, color, color
end

return {
    rgba = rgba,
    bw2rgb = bw2rgb,
    bw2rgba = bw2rgba,
    yuv_converter = yuv_converter,
}
