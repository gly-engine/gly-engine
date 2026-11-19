local math = require('math')
local floor = math.floor

local xor8, t0, t1, t2, t3

local function build()
    xor8 = {}
    for a = 0, 255 do
        for b = 0, 255 do
            local result, bit, x, y = 0, 1, a, b
            for _ = 1, 8 do
                if x % 2 ~= y % 2 then
                    result = result + bit
                end
                x, y, bit = floor(x / 2), floor(y / 2), bit * 2
            end
            xor8[a * 256 + b] = result
        end
    end

    t0, t1, t2, t3 = {}, {}, {}, {}
    for index = 0, 255 do
        local c0, c1, c2, c3 = index, 0, 0, 0
        for _ = 1, 8 do
            local lsb = c0 % 2
            c0 = floor(c0 / 2) + (c1 % 2) * 128
            c1 = floor(c1 / 2) + (c2 % 2) * 128
            c2 = floor(c2 / 2) + (c3 % 2) * 128
            c3 = floor(c3 / 2)
            if lsb == 1 then
                c0 = xor8[c0 * 256 + 0x20]
                c1 = xor8[c1 * 256 + 0x83]
                c2 = xor8[c2 * 256 + 0xB8]
                c3 = xor8[c3 * 256 + 0xED]
            end
        end
        t0[index], t1[index], t2[index], t3[index] = c0, c1, c2, c3
    end
end

local function crc32(str, crc)
    if not xor8 then
        build()
    end

    crc = crc or 0
    local c0 = 255 - crc % 256
    local c1 = 255 - floor(crc / 256) % 256
    local c2 = 255 - floor(crc / 65536) % 256
    local c3 = 255 - floor(crc / 16777216) % 256

    for index = 1, #str do
        local slot = xor8[c0 * 256 + str:byte(index)]
        c0 = xor8[t0[slot] * 256 + c1]
        c1 = xor8[t1[slot] * 256 + c2]
        c2 = xor8[t2[slot] * 256 + c3]
        c3 = t3[slot]
    end

    return (255 - c3) * 2^24 + (255 - c2) * 65536 + (255 - c1) * 256 + (255 - c0)
end

return {
    crc32 = crc32
}
