local math = require('math')
local deflate = require('source/third_party/safeteewow_libdeflate')
local hash = require('source/shared/hash/crc32')

local floor = math.floor

--! magic, deflate method, no flags, no mtime, no extra flags, unknown os
local HEADER = '\31\139\8\0\0\0\0\0\0\255'

local function le32(value)
    return string.char(
        value % 256,
        floor(value / 256) % 256,
        floor(value / 65536) % 256,
        floor(value / 16777216) % 256
    )
end

local function encode(body, options)
    local level = options and options.level or 6
    local packed = deflate:CompressDeflate(body, {level = level})
    return HEADER..packed..le32(hash.crc32(body))..le32(#body % 2^32)
end

return {
    encode = encode
}
