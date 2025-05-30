local test = require('teste/framework/microtest')
local protocol_http = require('ee/engine/protocol/http_fsb09')

local std = {bus = {listen = function() end}}
local http_reset = function() return protocol_http.install(std) end

function test_bug_53_incorrect_url_ipv4()
    http_reset().http.dns_state = 2
    local http_handler = protocol_http.handler
    local self = {
        url='http://192.168.0.1',
        promise = function () end,
        application = application
    }

    http_handler(self)
    assert(self.p_host == '192.168.0.1')
    assert(self.p_port == 80)
end

function test_bug_53_incorrect_url_ipv4_with_port()
    http_reset().http.dns_state = 2
    local protocol = protocol_http.install(std, {})
    local http_handler = protocol_http.handler
    local self = {
        url='http://192.168.0.2:8808',
        promise = function () end,
        application = application
    }

    http_handler(self)
    assert(self.p_host == '192.168.0.2')
    assert(self.p_port == 8808)
end

function test_bug_59_empty_content_response()
    local protocol = protocol_http.install(std, {})
    local http_handler = protocol_http.handler
    local self = {
        p_header_pos = 35,
        p_data = 'HTTP/1.0 204 OK\r\nConection: Close\r\n'
    }
    --[[
    application.internal.http.callbacks.http_headers(self)
    luaunit.assertEquals(self.p_content_size, 0)
    ]]
end

test.unit(_G)
