local test = require('tests/framework/microtest')
local deflate = require('source/third_party/safeteewow_libdeflate')
local ipk_encode = require('source/shared/archive/ipk/encode')

local CONTROL = 'Package: com.test.app\nVersion: 1.2.3\nDescription: test\n multi line\n'

local function ar_members(ipk)
    local members, pos = {}, 9
    assert(ipk:sub(1, 8) == '!<arch>\n')
    while pos <= #ipk do
        local name = ipk:sub(pos, pos + 15):gsub('%s+$', ''):gsub('/$', '')
        local size = tonumber((ipk:sub(pos + 48, pos + 57):gsub('%s+$', '')))
        members[#members + 1] = name
        members[name] = ipk:sub(pos + 60, pos + 59 + size)
        pos = pos + 60 + size + size % 2
    end
    return members
end

local function gunzip(body)
    return deflate:DecompressDeflate(body:sub(11, -9))
end

local function untar(body)
    local entries, pos = {}, 1
    while pos + 512 <= #body and body:byte(pos) ~= 0 do
        local name = body:sub(pos, pos + 99):gsub('%z+$', '')
        local prefix = body:sub(pos + 345, pos + 499):gsub('%z+$', '')
        local mode = tonumber(body:sub(pos + 100, pos + 106), 8)
        local size = tonumber(body:sub(pos + 124, pos + 134), 8)
        local full = #prefix > 0 and prefix..'/'..name or name
        entries[#entries + 1] = full
        entries[full] = {mode = string.format('%o', mode), body = body:sub(pos + 512, pos + 511 + size)}
        pos = pos + 512 + math.ceil(size / 512) * 512
    end
    return entries
end

local function build(control, files)
    return ipk_encode.encode(control, files or {{name = 'usr/bin/run', body = '#!/bin/sh\n'}})
end

function test_ipk_encode_layout()
    local name, ipk = build(CONTROL, {
        {name = 'usr/bin/run', body = '#!/bin/sh\n', mode = tonumber('755', 8)},
        {name = 'usr/share/app/logo.png', body = 'png'},
        {name = 'readme.txt', body = 'hi'}
    })
    local members = ar_members(ipk)
    assert(name == 'com.test.app_1.2.3_all.ipk')
    assert(members[1] == 'debian-binary' and members[2] == 'control.tar.gz' and members[3] == 'data.tar.gz')
    assert(members['debian-binary'] == '2.0\n')

    local data = untar(gunzip(members['data.tar.gz']))
    assert(data[1] == './')
    assert(data['./readme.txt'].mode == '644' and data['./readme.txt'].body == 'hi')
    assert(data['./usr/'].mode == '755')
    assert(data['./usr/bin/'].mode == '755')
    assert(data['./usr/bin/run'].mode == '755')
    assert(data['./usr/bin/run'].body == '#!/bin/sh\n')
    assert(data['./usr/share/app/logo.png'].mode == '644')
end

function test_ipk_encode_control()
    local _, ipk = build(CONTROL..'Installed-Size: 1\nArchitecture: armv7\n')
    local control = untar(gunzip(ar_members(ipk)['control.tar.gz']))
    assert(control[1] == './control' and control['./control'].mode == '644')
    assert(control['./control'].body == CONTROL..'Architecture: armv7\nInstalled-Size: 10\n')
    assert(_ == 'com.test.app_1.2.3_armv7.ipk')

    _, ipk = build(CONTROL)
    control = untar(gunzip(ar_members(ipk)['control.tar.gz']))
    assert(control['./control'].body == CONTROL..'Architecture: all\nInstalled-Size: 10\n')
end

function test_ipk_encode_free_naming()
    assert(build('Package: app\nVersion: 1.0\n') == 'app_1.0_all.ipk')
    assert(build('Package: app\nVersion: 1.0-r1\nDepends: libc (>= 2.0~rc1)\n') == 'app_1.0-r1_all.ipk')
end

function test_ipk_encode_invalid()
    local cases = {
        {'Version: 1.0.0\n', 'missing the "Package:" field'},
        {'Package: app\n', 'missing the "Version:" field'},
        {'Package: my app\nVersion: 1.0\n', 'cannot have spaces'},
        {'Package: app\nVersion: 1.0\nArchitecture: a_b\n', 'cannot have spaces'}
    }
    for _, case in ipairs(cases) do
        local name, err = build(case[1])
        assert(name == nil and err:find(case[2], 1, true), case[2]..': '..tostring(err))
    end
    for _, unsafe in ipairs({'/etc/passwd', '../x', 'a/../../x', 'a\\b'}) do
        local name, err = build(CONTROL, {{name = unsafe, body = ''}})
        assert(name == nil and err:find('data: unsafe path', 1, true), unsafe)
    end
end

test.unit(_G)
