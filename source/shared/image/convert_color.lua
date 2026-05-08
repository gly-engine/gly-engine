local math = require('math')
local floor = math.floor

local function bw2rgba(c)
    if c ~= 0 then return 0x000000FF end
    return 0xFFFFFFFF
end

local function bw2rgb(c)
    if c ~= 0 then return 0x000000 end
    return 0xFFFFFF
end

local function clamp(v)
    if v < 0 then return 0 end
    if v > 255 then return 255 end
    return v
end

local function yuv2rgb(y, u, v)
    local r = y + floor((v * 1436) / 1024)
    local g = y - floor((u * 352 + v * 731) / 1024)
    local b = y + floor((u * 1815) / 1024)
    return clamp(r), clamp(g), clamp(b)
end

return {
    bw2rgb = bw2rgb,
    bw2rgba = bw2rgba,
    yuv2rgb = yuv2rgb
}
