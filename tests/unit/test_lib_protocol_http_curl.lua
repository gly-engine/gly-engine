local test = require('tests/framework/microtest')
local mock_io = require('tests/mock/io')
local protocol_http = require('source/engine/protocol/http_curl')

local mock_popen = mock_io.popen({
    ['curl -L --silent --insecure -w "\n%{http_code}" -X GET pudim.com.br'] = {
        read=function () return 'i love pudim!\n200' end,
        close=function () return true, nil end
    },
    ['curl -L --silent --insecure -w "\n%{http_code}" -X POST -H "Authorization: bearer secret" pudim.com.br'] = {
        read=function () return 'method not allowed!\n403' end,
        close=function () return true, nil end
    },
    ['curl -L --silent --insecure -w "\n%{http_code}" -X POST pudim.com.br?foo=zig&bar=zag&z=zoom'] = {
        read=function () return 'me too!\n201' end,
        close=function () return true, nil end
    },
    ['curl -L --silent --insecure -w "\n%{http_code}" --HEAD '] = {
        read=function () return '' end,
        close=function () return false, 'no URL specified!' end
    },
    ['curl -L --silent --insecure -w "\n%{http_code}" -X POST -d \'UPPERCASE_CONTENT\' pudim.com.br'] = {
        read=function () return 'uppercase_content\n201' end,
        close=function () return true, nil end
    },
})

local function set(std)
    return function(key, value)
        std.http[key] = value
    end
end

function test_http_get_200()
    local std = {http={}}
    io.popen = mock_popen
    
    protocol_http.handler({
        set = set(std),
        std = std,
        url = 'pudim.com.br',
        method = 'GET'
    })

    assert(std.http.ok == true)
    assert(std.http.error == nil)
    assert(std.http.status == 200)
    assert(std.http.body == 'i love pudim!') -- same
end

function test_http_post_201()
    local std = {http={}}
    io.popen = mock_popen
    
    protocol_http.handler({
        set = set(std),
        std = std,
        param_list = {'foo', 'bar', 'z'},
        param_dict = {
            ['foo'] = 'zig',
            ['bar'] = 'zag',
            ['z'] = 'zoom'
        },
        url = 'pudim.com.br',
        method = 'POST'
    })

    assert(std.http.ok == true)
    assert(std.http.error == nil)
    assert(std.http.status == 201)
    assert(std.http.body == 'me too!')
end

function test_http_post_403()
    local std = {http={}}
    io.popen = mock_popen
    
    protocol_http.handler({
        set = set(std),
        std = std,
        header_list = {'Authorization'},
        header_dict = {['Authorization'] = 'bearer secret'},
        url = 'pudim.com.br',
        method = 'POST'
    })

    assert(std.http.ok == false)
    assert(std.http.error == nil)
    assert(std.http.status == 403)
    assert(std.http.body == 'method not allowed!')
end

function test_http_head_error()
    local std = {http={}}
    io.popen = mock_popen
    
    protocol_http.handler({
        set = set(std),
        std = std,
        url = '',
        method = 'HEAD'
    })

    assert(std.http.ok == false)
    assert(std.http.error == 'no URL specified!')
    assert(std.http.status == nil)
    assert(std.http.body == nil)
end

function test_http_popen_error()
    local std = {http={}}
    io.popen = nil
    
    protocol_http.handler({
        set = set(std),
        std = std,
        url = 'pudim.com.br',
        method = 'GET'
    })

    assert(std.http.ok == false)
    assert(std.http.error == 'failed to spawn process!')
    assert(std.http.status == nil)
    assert(std.http.body == nil)
end

function test_http_post_with_body()
    local std = {http={}}
    io.popen = mock_popen
    
    protocol_http.handler({
        set = set(std),
        std = std,
        url = 'pudim.com.br',
        method = 'POST',
        body_content = 'UPPERCASE_CONTENT'
    })

    assert(std.http.ok == true)
    assert(std.http.error == nil)
    assert(std.http.status == 201)
    assert(std.http.body == 'uppercase_content')
end

test.unit(_G)
