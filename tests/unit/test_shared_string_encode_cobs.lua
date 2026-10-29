local test = require('tests/framework/microtest')
local cobs = require('source/shared/string/encode/cobs')

local function bytes(...)
    return string.char(...)
end

local function range(first, last)
    local out = {}
    for value = first, last do
        out[#out + 1] = string.char(value)
    end
    return table.concat(out)
end

local function check(plain, encoded)
    assert(cobs.encode(plain) == encoded)
    assert(cobs.decode(encoded) == plain)
end

function test_cobs_reference_examples()
    check('', bytes(1))
    check(bytes(0), bytes(1, 1))
    check(bytes(0, 0), bytes(1, 1, 1))
    check(bytes(0, 0x11, 0), bytes(1, 2, 0x11, 1))
    check(bytes(0x11, 0x22, 0, 0x33), bytes(3, 0x11, 0x22, 2, 0x33))
    check(bytes(0x11, 0x22, 0x33, 0x44), bytes(5, 0x11, 0x22, 0x33, 0x44))
    check(bytes(0x11, 0, 0, 0), bytes(2, 0x11, 1, 1, 1))
end

function test_cobs_full_blocks()
    check(range(1, 254), bytes(255)..range(1, 254))
    check(range(0, 254), bytes(1, 255)..range(1, 254))
    check(range(1, 255), bytes(255)..range(1, 254)..bytes(2, 255))
end

function test_cobs_has_no_zero()
    local every = range(0, 255)..range(0, 255)..range(0, 255)
    local encoded = cobs.encode(every)
    assert(not encoded:find('\0', 1, true))
    assert(cobs.decode(encoded) == every)
end

function test_cobs_stream_any_split()
    local plain = range(0, 255)..string.rep('\0', 300)..range(1, 255)..'end'
    local encoded = cobs.encode(plain)
    for size = 1, 7 do
        local decoder = cobs.decoder()
        local parts = {}
        for index = 1, #encoded, size do
            parts[#parts + 1] = decoder:push(encoded:sub(index, index + size - 1))
        end
        assert(table.concat(parts) == plain)
    end
end

function test_cobs_refuses_zero()
    assert(not pcall(cobs.decode, bytes(2, 0x11, 0, 0x33)))
end

test.unit(_G)
