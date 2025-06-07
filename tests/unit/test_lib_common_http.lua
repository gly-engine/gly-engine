local test = require('tests/framework/microtest')
local zeebo_http = require('source/engine/api/io/http')
local mock_http = require('tests/mock/protocol_http')
local zeebo_pipeline = require('source/shared/functional/pipeline')
local std = {node={emit=function()end}}
local engine = {current={callbacks={}}}

local http_handler = mock_http.requests({
    ['example.com/status200'] = {
        ok = true,
        status = 200
    },
    ['example.com/set-status-body-param1-param2'] = {
        ok = true,
        status = function(http_object)
            return tonumber(http_object.param_dict[http_object.param_list[1]])
        end,
        body = function(http_object)
            return http_object.param_dict[http_object.param_list[2]]
        end
    },
    ['example.com/set-body-lower-with-body'] = {
        ok = true,
        status = 201,
        body = function(http_object)
            return string.lower(http_object.body_content)
        end
    },['example.com/status500'] = {
            ok = false,
            status = 500
        }

})

zeebo_http.install(std, engine, {handler=http_handler})

function test_http_head_200()
    local status = 0
    local ok = nil

    std.http.head('example.com/status200')
        :success(function (std) ok, status = true, std.http.status end)
        :failed(function (std) ok, status = false, std.http.status end)
        :error(function() ok, status = false, -1 end)
        :run()
    assert(ok == true)
    assert(status == 200)
end

function test_http_get_500()
    local status = 0
    local ok = nil

    std.http.head('example.com/status500')
        :success(function (std) ok, status = true, std.http.status end)
        :failed(function (std) ok, status = false, std.http.status end)
        :error(function() ok, status = false, -1 end)
        :run()

    assert(status == 500)
    assert(ok == false) 
end

function test_http_head_404()
    local status = 0
    local ok = nil

    std.http.head('example.com/status404')
        :success(function (std) ok, status = true, std.http.status end)
        :failed(function (std) ok, status = false, std.http.status end)
        :error(function() ok, status = false, -1 end)
        :run()

    assert(ok == false)
    assert(status == 404)
end

function test_http_head_error()
    local message = nil
    local status = 0
    local ok = nil

    std.http.head()
        :success(function (std) ok, status = true, std.http.status end)
        :failed(function (std) ok, status = false, std.http.status end)
        :error(function() ok, status, message = false, -1, std.http.error end)
        :run()

    assert(ok == false)
    assert(status == -1)
    assert(message == 'URL not set!')
end

function test_http_get_201()
    local status = 0
    local body = ''

    std.http.head('example.com/set-status-body-param1-param2')
        :param('param1', 201)
        :param('param2', 'foobarz')
        :success(function (std)
            status = std.http.status
            body = std.http.body
        end)
        :failed(function (std)
            status = std.http.status
            body = std.http.body
        end)
        :error(function() status = -1 end)
        :run()

    assert(status == 201)
    assert(body == 'foobarz')
end

function test_http_post_body()
    local ok, sttus, body = false, 0, nil

    std.http.post('example.com/set-body-lower-with-body')
        :body('FOOBARZ')
        :success(function (std) ok, status, body = std.http.ok, std.http.status, std.http.body end)
        :failed(function (std) ok, status = std.http.ok, std.http.status end)
        :error(function() ok, status = false, -1 end)
        :run()


    assert(ok == true)
    assert(status == 201)
    assert(body == 'foobarz')
end

function test_http_fast()
    local request = std.http.get('example.com/status200')
    request:fast()
    assert(request.speed == '_fast')
end

function test_http_header()
    local request = std.http.get('example.com/status200')
    request:header('Content-Type', 'application/json')
    assert(request.header_dict['Content-Type'] == 'application/json')
end

function test_http_promise()
    local stop_called = false
    zeebo_pipeline.stop = function(self) stop_called = true end
    local request = std.http.get('example.com/status200')
    request:promise()
    assert(stop_called == true)
end

function test_http_resolve()
    local resume_called = false
    zeebo_pipeline.resume = function(self) resume_called = true end
    local request = std.http.get('example.com/status200')
    request:resolve()
    assert(resume_called == true)
end


function test_http_set()
    local mock_std = { http = {}}
    
    local set_function = function (key, value)
        mock_std.http[key] = value
    end
    set_function('timeout', 5000)
    assert(mock_std.http.timeout == 5000)
end

function test_protocol_with_install()
    local install_called = false
    local protocol = {
        handler = function() end,
        install = function(std, engine)
            install_called = true
            assert(std ~= nil)
            assert(engine ~= nil)
        end
    }
    local std = {}
    local engine = {}
    
    local http_module = require('source/engine/api/io/http')
    http_module.install(std, engine, protocol)
    assert(install_called == true)
end

function test_protocol_without_install()
    local protocol = {}
    local std = {}
    local engine = {}
    
    if protocol.install then 
        protocol.install(std, engine)
    end
    assert(true) -- ??

end

test.unit(_G)
