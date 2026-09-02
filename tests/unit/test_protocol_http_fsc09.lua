local test = require('tests/framework/microtest')
local protocol = require('ee/engine/protocol/http_fsc09')

local callback
local sessions = {}
event = {
    post = function(request)
        sessions[request.uri] = request.session
    end
}

local std = {
    bus = {
        listen = function(_, handler)
            callback = handler
        end
    }
}
local engine = {envs = {['ginga.fsc09'] = 'true'}}
protocol.install(std, engine)

local function request(url, method)
    local response = {}
    local self = {
        url = url,
        method = method or 'GET',
        param_list = {},
        param_dict = {},
        header_dict = {},
        promise = function() end,
        resolve = function()
            response.resolved = true
        end,
        set = function(key, value)
            response[key] = value
        end
    }
    protocol.handler(self)
    return response, self
end

function test_fsc09_isolates_concurrent_responses()
    local first = request('http://first')
    local second = request('http://second')
    local first_session = sessions['http://first']
    local second_session = sessions['http://second']

    callback({class = 'http', session = first_session, headers = {['Content-Length'] = '4'}, code = 200})
    callback({class = 'http', session = second_session, headers = {['Content-Length'] = '4'}, code = 201})
    callback({class = 'http', session = first_session, body = 'ab'})
    callback({class = 'http', session = second_session, body = 'WX'})
    callback({class = 'http', session = first_session, body = 'cd'})
    callback({class = 'http', session = second_session, body = 'YZ'})

    assert(first.resolved and second.resolved)
    assert(first.status == 200 and first.body == 'abcd')
    assert(second.status == 201 and second.body == 'WXYZ')
    assert(first.ok and second.ok)
end

function test_fsc09_resolves_body_without_content_length()
    local response = request('http://without-length')
    local session = sessions['http://without-length']
    callback({class = 'http', session = session, headers = {}, code = 200})
    callback({class = 'http', session = session, body = 'complete'})
    assert(response.resolved and response.body == 'complete')
end

function test_fsc09_waits_for_chunked_finish()
    local response = request('http://chunked')
    local session = sessions['http://chunked']
    callback({class = 'http', session = session, headers = {['Transfer-Encoding'] = 'chunked'}, code = 200})
    callback({class = 'http', session = session, body = 'ab'})
    assert(not response.resolved)
    callback({class = 'http', session = session, body = 'cd', finished = true})
    assert(response.resolved and response.body == 'abcd')
end

function test_fsc09_resolves_head_without_body()
    local response = request('http://head', 'HEAD')
    local session = sessions['http://head']
    callback({class = 'http', session = session, headers = {['Content-Length'] = '50'}, code = 200})
    assert(response.resolved and response.body == '')
end

function test_fsc09_resolves_no_content_status()
    local response = request('http://no-content')
    local session = sessions['http://no-content']
    callback({class = 'http', session = session, headers = {}, code = 204})
    assert(response.resolved and response.body == '')
end

function test_fsc09_streams_without_retaining_body()
    local response, self = request('http://stream')
    local session = sessions['http://stream']
    local chunks = {}
    self.stream = function(chunk)
        chunks[#chunks + 1] = chunk
    end
    self.discard_body = true
    callback({class = 'http', session = session, headers = {['Content-Length'] = '4'}, code = 200})
    callback({class = 'http', session = session, body = 'ab'})
    callback({class = 'http', session = session, body = 'cd'})
    assert(response.resolved and response.body == '')
    assert(table.concat(chunks) == 'abcd')
end

test.unit(_G)
