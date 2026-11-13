local test = require('tests/framework/microtest')
local ar = require('source/shared/string/encode/ar')

function test_ar_empty()
    assert(ar.encode({}) == '!<arch>\n')
end

function test_ar_single_member()
    local out = ar.encode({{name='debian-binary', body='2.0\n'}})
    local header = out:sub(9, 68)
    assert(#out == 8 + 60 + 4)
    assert(header:sub(1, 16) == 'debian-binary/  ')
    assert(header:sub(17, 28) == '0           ')
    assert(header:sub(41, 48) == '100644  ')
    assert(header:sub(49, 58) == '4         ')
    assert(header:sub(59, 60) == '`\n')
    assert(out:sub(69) == '2.0\n')
end

function test_ar_odd_size_padding()
    local out = ar.encode({{name='a', body='abc'}, {name='b', body='z'}})
    assert(out:sub(69, 72) == 'abc\n')
    assert(out:sub(73, 74) == 'b/')
    assert(#out == 8 + 60 + 4 + 60 + 2)
end

function test_ar_custom_fields()
    local out = ar.encode({{name='x', body='', mode='755', mtime=1700000000, uid=1000, gid=1000}})
    assert(out:sub(9 + 16, 9 + 27) == '1700000000  ')
    assert(out:sub(9 + 28, 9 + 33) == '1000  ')
    assert(out:sub(9 + 34, 9 + 39) == '1000  ')
    assert(out:sub(9 + 40, 9 + 47) == '755     ')
end

function test_ar_numeric_mode()
    local out = ar.encode({{name='x', body='', mode=tonumber('100755', 8)}})
    assert(out:sub(9 + 40, 9 + 47) == '100755  ')
end

function test_ar_long_names()
    local name1 = 'um_nome_bem_comprido.txt'
    local name2 = 'outro_nome_comprido.txt'
    local out = ar.encode({{name=name1, body='1'}, {name='short', body='2'}, {name=name2, body='3'}})
    local table_body = name1..'/\n'..name2..'/\n'
    assert(out:sub(9, 10) == '//')
    assert(tonumber(out:sub(9 + 48, 9 + 57):match('%d+')) == #table_body)
    assert(out:sub(69, 68 + #table_body) == table_body)
    assert(out:find(string.format('%-16s', '/0'), 1, true))
    assert(out:find(string.format('%-16s', 'short/'), 1, true))
    assert(out:find('/'..(#name1 + 2)..' ', 1, true))
end

function test_ar_invalid_names()
    assert(not pcall(ar.encode, {{name='', body=''}}))
    assert(not pcall(ar.encode, {{body=''}}))
    assert(not pcall(ar.encode, {{name='dir/file', body=''}}))
end

function test_ar_field_overflow()
    assert(not pcall(ar.encode, {{name='x', body='', uid=1234567}}))
end

test.unit(_G)
