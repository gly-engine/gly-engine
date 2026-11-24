local test = require('tests/framework/microtest')
local ipk_encode = require('source/shared/archive/ipk/encode')
local ipk_decode = require('source/shared/archive/ipk/decode')

local CONTROL = 'Package: com.test.app\nVersion: 1.2.3\nDescription: test\n multi line\n'
local SEAL = 'SEALED:'

--! @short a protector without crypto, seal is a prefix and the signature is fixed
local function fake_protect(key, signature)
    return {
        key = key or 'KEYID',
        private = true,
        seal = function(data) return SEAL..data end,
        sign = function() return signature or 'SIG==' end,
        unseal = function(sealed) return (sealed:gsub('^'..SEAL, '')) end,
        verify = function(_, sealed, given)
            return given == (signature or 'SIG==') and sealed:sub(1, #SEAL) == SEAL
        end
    }
end

local function files_by_name(files)
    local map = {}
    for _, file in ipairs(files) do
        map[file.name] = file
    end
    return map
end

local function build(files, protect)
    local name, ipk = ipk_encode.encode(CONTROL, files, {protect = protect})
    assert(name, ipk)
    return ipk
end

function test_decode_gives_back_what_encode_took()
    local ipk = build({
        {name = 'usr/bin/run', body = '#!/bin/sh\n', mode = tonumber('755', 8)},
        {name = 'usr/share/app/index.html', body = '<html>'}
    })

    local control, files = ipk_decode.decode(ipk)
    local map = files_by_name(files)

    assert(control, files)
    assert(#files == 2, 'only the files, never the folder entries')
    assert(map['usr/bin/run'].body == '#!/bin/sh\n')
    assert(map['usr/share/app/index.html'].body == '<html>')
end

function test_decode_keeps_the_executable_bit()
    local ipk = build({{name = 'usr/bin/run', body = 'x', mode = tonumber('755', 8)}})

    local _, files = ipk_decode.decode(ipk)

    assert(files[1].mode == tonumber('755', 8), 'the mode is what puts the bit back on disk')
end

function test_decode_drops_the_dot_slash_of_the_archive()
    local _, files = ipk_decode.decode(build({{name = 'usr/bin/run', body = 'x'}}))

    assert(files[1].name == 'usr/bin/run', 'the name is relative to the install root')
end

function test_decode_keeps_the_continuation_lines()
    local control = ipk_decode.decode(build({{name = 'a', body = 'x'}}))

    assert(control:find('Description: test\n multi line\n', 1, true), 'a folded field has to survive')
end

function test_decode_adds_the_fields_the_encode_computed()
    local control = ipk_decode.decode(build({{name = 'a', body = 'xyz'}}))

    assert(control:find('Architecture: all\n', 1, true), 'the effective control is the one in the package')
    assert(control:find('Installed-Size: 3\n', 1, true))
end

function test_decode_rejects_what_is_not_a_package()
    local control, err = ipk_decode.decode('Package: com.test.app\n')

    assert(not control and err:find('not an ar archive'), 'got: '..tostring(err))
end

function test_decode_rejects_a_truncated_package()
    local ipk = build({{name = 'a', body = 'x'}})

    assert(not ipk_decode.decode(ipk:sub(1, #ipk - 40)), 'half a package is not a package')
end

function test_decode_opens_a_protected_package()
    local ipk = build({{name = 'usr/bin/run', body = 'secret'}}, fake_protect())

    local control, files = ipk_decode.decode(ipk, {protect = fake_protect()})

    assert(control, files)
    assert(files[1].body == 'secret', 'the data comes back in the clear')
    assert(control:find('Key: KEYID\n', 1, true), 'the control still says who signed it')
end

function test_decode_asks_for_the_key_of_a_protected_package()
    local ipk = build({{name = 'a', body = 'x'}}, fake_protect())

    local control, err = ipk_decode.decode(ipk)

    assert(not control and err:find('it needs the key that signed it'), 'got: '..tostring(err))
end

function test_decode_refuses_another_key()
    local ipk = build({{name = 'a', body = 'x'}}, fake_protect('AAAA'))

    local control, err = ipk_decode.decode(ipk, {protect = fake_protect('BBBB')})

    assert(not control and err:find('signed by the key AAAA'), 'got: '..tostring(err))
end

function test_decode_refuses_a_broken_signature()
    local ipk = build({{name = 'a', body = 'x'}}, fake_protect('KEYID', 'WRONG=='))
    local protect = fake_protect('KEYID')

    local control, err = ipk_decode.decode(ipk, {protect = protect})

    assert(not control and err:find('invalid signature'), 'got: '..tostring(err))
end

test.unit(_G)
