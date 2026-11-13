local test = require('tests/framework/microtest')
local tar = require('source/shared/string/encode/tar')

local function field(block, offset, width)
    local value = block:sub(offset + 1, offset + width)
    local nul = value:find('\0', 1, true)
    return nul and value:sub(1, nul - 1) or value
end

local function valid_checksum(block)
    local sum = 0
    for index = 1, 512 do
        if index > 148 and index <= 156 then
            sum = sum + 32
        else
            sum = sum + block:byte(index)
        end
    end
    return tonumber(field(block, 148, 8), 8) == sum
end

function test_tar_empty()
    local out = tar.encode({})
    assert(out == string.rep('\0', 1024))
end

function test_tar_single_file()
    local out = tar.encode({{name='./control', body='Package: hello\n'}})
    local block = out:sub(1, 512)
    assert(#out == 512 + 512 + 1024)
    assert(field(block, 0, 100) == './control')
    assert(field(block, 100, 8) == '0000644')
    assert(tonumber(field(block, 124, 12), 8) == 15)
    assert(block:sub(157, 157) == '0')
    assert(block:sub(258, 263) == 'ustar\0')
    assert(block:sub(264, 265) == '00')
    assert(field(block, 265, 32) == 'root')
    assert(valid_checksum(block))
    assert(out:sub(513, 527) == 'Package: hello\n')
    assert(out:sub(528, 1024) == string.rep('\0', 497))
end

function test_tar_exact_block_body()
    local out = tar.encode({{name='a', body=string.rep('x', 512)}})
    assert(#out == 512 + 512 + 1024)
end

function test_tar_directory()
    local block = tar.encode({{name='./usr/'}}):sub(1, 512)
    assert(block:sub(157, 157) == '5')
    assert(field(block, 100, 8) == '0000755')
    assert(tonumber(field(block, 124, 12), 8) == 0)
    assert(valid_checksum(block))
end

function test_tar_symlink()
    local out = tar.encode({{name='./usr/bin/hi', link='hello', body='ignored'}})
    local block = out:sub(1, 512)
    assert(#out == 512 + 1024)
    assert(block:sub(157, 157) == '2')
    assert(field(block, 157, 100) == 'hello')
    assert(field(block, 100, 8) == '0000777')
    assert(valid_checksum(block))
end

function test_tar_custom_mode()
    local block1 = tar.encode({{name='a', body='', mode='755'}}):sub(1, 512)
    local block2 = tar.encode({{name='a', body='', mode=tonumber('700', 8)}}):sub(1, 512)
    assert(field(block1, 100, 8) == '0000755')
    assert(field(block2, 100, 8) == '0000700')
end

function test_tar_long_name()
    local dir = string.rep('a', 60)
    local file = string.rep('b', 90)..'.txt'
    local block = tar.encode({{name=dir..'/'..file, body=''}}):sub(1, 512)
    assert(field(block, 0, 100) == file)
    assert(field(block, 345, 155) == dir)
    assert(valid_checksum(block))
end

function test_tar_name_too_long()
    assert(not pcall(tar.encode, {{name=string.rep('a', 120), body=''}}))
    assert(not pcall(tar.encode, {{name=string.rep('a', 200)..'/b', body=''}}))
end

function test_tar_invalid_name()
    assert(not pcall(tar.encode, {{name='', body=''}}))
    assert(not pcall(tar.encode, {{body=''}}))
end

test.unit(_G)
