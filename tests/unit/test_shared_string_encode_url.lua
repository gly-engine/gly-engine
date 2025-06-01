local test = require('tests/framework/microtest')
local str_url = require('source/shared/string/encode/url')

function test_no_params()
    local query = str_url.search_param({}, {})
    assert(query == '')
end

function test_one_param()
    local query = str_url.search_param({'foo'}, {foo='bar'})
    assert(query == '?foo=bar')
end

function test_three_params()
    local query = str_url.search_param({'foo', 'z'}, {foo='bar', z='zoom'})
    assert(query == '?foo=bar&z=zoom')
end

function test_four_params_with_null()
    local query = str_url.search_param({'foo', 'z', 'zig'}, {foo='bar', z='zoom'})
    assert(query == '?foo=bar&z=zoom&zig=')
end

test.unit(_G)
