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

--- a compressed response declares the bytes on the wire, and ginga hands over the
--- inflated ones: the declared length is reached long before the body is whole, and
--- resolving there used to hand half a zcis to the decoder ("truncated ar member").
function test_fsc09_waits_past_a_compressed_length()
    local response = request('http://gzipped')
    local session = sessions['http://gzipped']
    callback({class = 'http', session = session, code = 200,
              headers = {['Content-Length'] = '8', ['Content-Encoding'] = 'gzip'}})
    callback({class = 'http', session = session, body = 'aaaaaaaa'})
    assert(not response.resolved, 'the wire length is not the inflated length')
    callback({class = 'http', session = session, body = 'bbbb'})
    assert(not response.resolved)
    callback({class = 'http', session = session, finished = true})
    assert(response.resolved and response.body == 'aaaaaaaabbbb')
end

-- some boxes lowercase the response headers and some do not
function test_fsc09_reads_a_lowercased_length()
    local response = request('http://lowercase')
    local session = sessions['http://lowercase']
    callback({class = 'http', session = session, headers = {['content-length'] = '4'}, code = 200})
    callback({class = 'http', session = session, body = 'ab'})
    assert(not response.resolved, 'half the body is not the body')
    callback({class = 'http', session = session, body = 'cd'})
    assert(response.resolved and response.body == 'abcd')
end

-- the request says identity so the length it is given is the length that arrives
function test_fsc09_asks_for_identity_encoding()
    local _, self = request('http://plain')
    assert(self.header_dict['Accept-Encoding'] == 'identity')
end

test.unit(_G)
