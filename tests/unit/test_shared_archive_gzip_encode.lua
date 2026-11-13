local test = require('tests/framework/microtest')
local deflate = require('source/third_party/safeteewow_libdeflate')
local hash = require('source/shared/hash/crc32')
local gzip_encode = require('source/shared/archive/gzip/encode')

local function u32(buf, pos)
    local a, b, c, d = buf:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 2^24
end

local function decode(out)
    local body = deflate:DecompressDeflate(out:sub(11, -9))
    return body, u32(out, #out - 7), u32(out, #out - 3)
end

function test_gzip_encode_header()
    local out = gzip_encode.encode('gly')
    assert(out:sub(1, 4) == '\31\139\8\0')
    assert(out:sub(10, 10) == '\255')
end

function test_gzip_encode_roundtrip()
    local text = string.rep('gly engine gzip ', 500)
    local out = gzip_encode.encode(text)
    local body, crc, size = decode(out)
    assert(#out < #text)
    assert(body == text)
    assert(crc == hash.crc32(text))
    assert(size == #text)
end

function test_gzip_encode_empty()
    local body, crc, size = decode(gzip_encode.encode(''))
    assert(body == '')
    assert(crc == 0)
    assert(size == 0)
end

function test_gzip_encode_level()
    local text = string.rep('abcdefgh', 1000)
    local body = decode(gzip_encode.encode(text, {level = 1}))
    assert(body == text)
end

test.unit(_G)
