local deep_copy = require('source/shared/table/deep_copy')
local str_url = require('source/shared/string/encode/url')
local user_agent = require('source/agent')
local request_dict = {}
local response_dict = {}

local function handler(self)
    local uri = self.url..str_url.search_param(self.param_list, self.param_dict)
    local session = tonumber(tostring(self):match("0x(%x+)$"), 16)
    local allow_body = self.method ~= 'GET' and self.method ~= 'HEAD'
    local method = string.lower(self.method)
    local body = allow_body and self.body
    local headers = self.header_dict

    if not headers['User-Agent'] then
        headers['User-Agent'] = user_agent
    end

    request_dict[session] = self
    response_dict[session] = {
        body = {},
        size = 0
    }

    self.promise()
    event.post({
        class = 'http',
        type = 'request',
        method = method,
        uri = uri,
        headers = headers,
        body = body,
        session = session
    })
end

local function callback(evt)
    if evt.class ~= 'http' then return end
    local empty = not evt.headers or not evt.body or not evt.code
    local raise_error = false
    local session = evt.session
    local self = request_dict[session]
    local response = response_dict[session]

    if not self or not response then return end

    if evt.error and #evt.error > 0 and empty then
        response.error = evt.error
        raise_error = true
    end

    if evt.headers then
        if evt.headers['Content-Length'] then
            response.content_length = tonumber(evt.headers['Content-Length'])
        end
        response.headers = deep_copy.table(evt.headers)
        local transfer_encoding = evt.headers['Transfer-Encoding']
        response.chunked = transfer_encoding
            and transfer_encoding:lower():find('chunked', 1, true) ~= nil
    end

    if evt.code then
        response.ok = 200 <= tonumber(evt.code) and tonumber(evt.code) < 300
        response.status = evt.code
    end

    if evt.body then
        if self.stream and response.ok ~= false then
            self.stream(evt.body)
        end
        if not self.discard_body then
            local body = response.body
            body[#body + 1] = evt.body
        end
        response.size = response.size + #evt.body
    end

    local status = tonumber(response.status)
    local bodyless = self.method == 'HEAD' or status == 204 or status == 304
    local complete_length = response.content_length and response.size >= response.content_length
        or response.content_length == nil and not response.chunked and evt.body ~= nil
    if evt.finished or raise_error or complete_length or bodyless then
        self.set('headers', response.headers)
        self.set('ok', response.ok)
        self.set('status', response.status)
        self.set('error', response.error)
        self.set('body', self.discard_body and '' or table.concat(response.body))
        request_dict[session] = nil
        response_dict[session] = nil
        self.resolve()
    end
end

local function install(std, engine)    
    if tostring(engine.envs['ginga.fsc09']) ~= 'true' then
        error('old device!')
    end
    std.bus.listen('ginga', callback)
end

local P = {
    install = install,
    handler = handler,
    has_ssl = true
}

return P
