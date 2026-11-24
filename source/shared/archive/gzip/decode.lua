--! @brief gzip reader, the counterpart of the gzip encode
local math = require('math')
local deflate = require('source/third_party/safeteewow_libdeflate')
local hash = require('source/shared/hash/crc32')

local FEXTRA, FNAME, FCOMMENT, FHCRC = 4, 8, 16, 2
local HEADER = 10
local TRAILER = 8

local function fail(message)
    error(message, 0)
end

local function has(flags, flag)
    return flags % (flag * 2) >= flag
end

--! @short little endian uint32, as a float on purpose
--! @details fengari wraps integer arithmetic at 32 bits, so the top byte has
--! to be scaled by a float literal or a crc past 2^31 comes back negative
local function le32(content, pos)
    local a, b, c, d = content:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 2^24
end

local function skip_string(content, pos)
    local stop = content:find('\0', pos, true)
    if not stop then
        fail('gzip: truncated header')
    end
    return stop + 1
end

local function decode(content)
    if #content < HEADER + TRAILER or content:byte(1) ~= 31 or content:byte(2) ~= 139 then
        fail('gzip: not a gzip stream')
    end
    if content:byte(3) ~= 8 then
        fail('gzip: unsupported compression method')
    end

    local flags = content:byte(4)
    local pos = HEADER + 1

    if has(flags, FEXTRA) then
        pos = pos + 2 + content:byte(pos) + content:byte(pos + 1) * 256
    end
    if has(flags, FNAME) then
        pos = skip_string(content, pos)
    end
    if has(flags, FCOMMENT) then
        pos = skip_string(content, pos)
    end
    if has(flags, FHCRC) then
        pos = pos + 2
    end
    if pos > #content - TRAILER then
        fail('gzip: truncated header')
    end

    local body, rest = deflate:DecompressDeflate(content:sub(pos))
    if not body then
        fail('gzip: invalid deflate stream')
    end
    if rest ~= TRAILER then
        fail('gzip: trailing garbage after the deflate stream')
    end

    local trailer = #content - TRAILER + 1
    if hash.crc32(body) ~= le32(content, trailer) then
        fail('gzip: checksum mismatch')
    end
    if #body % 2 ^ 32 ~= le32(content, trailer + 4) then
        fail('gzip: size mismatch')
    end

    return body
end

return {
    decode = decode
}
