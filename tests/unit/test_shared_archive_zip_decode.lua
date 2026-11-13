local test = require('tests/framework/microtest')
local zip = require('source/shared/archive/zip/decode')

local function unhex(str)
    return (str:gsub('..', function(byte) return string.char(tonumber(byte, 16)) end))
end

local FIXTURE = unhex(
    '504b0304140002000800e3766d5d8d48be0c510000007900000008000000636f6e662e6c75615d8a310e80200c00775e'..
    'd130e9428045175f03059a9076a9127f2f2b5e72d35db93929094397075d122e9bee0626ea067196e194b4235c606b7f'..
    'e1a75dd74159db5c433cfd5a1a526d3ad311bd41cee603504b03040a0002000000e3766d5dac2a93d802000000020000'..
    '0005000000612e7478746869504b01021e03140002000800e3766d5d8d48be0c51000000790000000800000000000000'..
    '01000000b48100000000636f6e662e6c7561504b01021e030a0002000000e3766d5dac2a93d802000000020000000500'..
    '00000000000001000000b48177000000612e747874504b05060000000002000200690000009c0000000a00636f6d656e'..
    '746172696f'
)

local CONF = 'function love.conf(t)\n'
    ..'    t.window.title = "gly gly gly gly gly"\n'
    ..'    t.window.width = 1280\n'
    ..'    t.window.height = 720\n'
    ..'end\n'

function test_zip_files()
    local list = zip.files(FIXTURE)
    assert(#list == 2)
    assert(list[1].name == 'conf.lua')
    assert(list[1].method == 8)
    assert(list[1].size == #CONF)
    assert(list[1].crc == 0x0cbe488d)
    assert(list[2].name == 'a.txt')
    assert(list[2].method == 0)
    assert(list[2].crc == 0xd8932aac)
end

function test_zip_find_deflate()
    assert(zip.find(FIXTURE, 'conf.lua') == CONF)
end

function test_zip_find_stored()
    assert(zip.find(FIXTURE, 'a.txt') == 'hi')
end

function test_zip_find_missing()
    assert(zip.find(FIXTURE, 'main.lua') == nil)
end

function test_zip_decode()
    local members = zip.decode(FIXTURE)
    assert(#members == 2)
    assert(members[1].name == 'conf.lua' and members[1].body == CONF)
    assert(members[2].name == 'a.txt' and members[2].body == 'hi')
end

function test_zip_corrupted_checksum()
    local list = zip.files(FIXTURE)
    local entry = list[2]
    local broken = FIXTURE:sub(1, entry.offset - 1)..'ho'..FIXTURE:sub(entry.offset + 2)
    assert(not pcall(zip.extract, broken, entry))
end

function test_zip_invalid()
    assert(not pcall(zip.files, 'not a zip file at all, just text'))
    assert(not pcall(zip.files, ''))
end

test.unit(_G)
