local test = require('tests/framework/microtest')
local hash = require('source/shared/hash/crc32')

function test_crc32_empty()
    assert(hash.crc32('') == 0)
end

function test_crc32_check_value()
    assert(hash.crc32('123456789') == 0xCBF43926)
end

function test_crc32_text()
    assert(hash.crc32('The quick brown fox jumps over the lazy dog') == 0x414FA339)
end

function test_crc32_binary()
    assert(hash.crc32('\0\255\0\255') == 0xB2DE047C)
end

function test_crc32_continuation()
    local whole = hash.crc32('hello world')
    local part = hash.crc32('world', hash.crc32('hello '))
    assert(whole == part)
end

test.unit(_G)
