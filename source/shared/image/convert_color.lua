local math = require('math')
local floor = math.floor
local inv_1024 = 1 / 1024

local function bw2rgba(c)
    if c ~= 0 then return 0x000000FF end
    return 0xFFFFFFFF
end

local function bw2rgb(c)
    if c ~= 0 then return 0x000000 end
    return 0xFFFFFF
end

local function yuv2rgb(y, u, v)
    local r = y + floor(v * 1436 * inv_1024)
    local g = y - floor((u * 352 + v * 731) * inv_1024)
    local b = y + floor(u * 1815 * inv_1024)
    if r < 0 then r = 0 elseif r > 255 then r = 255 end
    if g < 0 then g = 0 elseif g > 255 then g = 255 end
    if b < 0 then b = 0 elseif b > 255 then b = 255 end
    return r, g, b
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
    yuv2rgb = yuv2rgb,
}
