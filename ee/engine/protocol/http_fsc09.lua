local deep_copy = require('source/shared/table/deep_copy')
local str_url = require('source/shared/string/encode/url')
local user_agent = require('source/agent')
local content_length = {}
local request_dict = {}
local data_dict = {}
local status_dict = {}
local inflated_dict = {}

local function header_of(headers, wanted)
    for name, value in pairs(headers or {}) do
        if string.lower(tostring(name)) == wanted then
            return value
        end
    end
end

local function bodyless(method, status)
    return method == 'HEAD' or status == 204 or status == 205 or status == 304
end

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

    if not headers['Accept-Encoding'] then
        headers['Accept-Encoding'] = 'identity'
    end

    data_dict[session] = ''
    request_dict[session] = self
    status_dict[session] = nil
    content_length[session] = nil
    inflated_dict[session] = false

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

local function complete(self, session, evt)
    if bodyless(self.method, status_dict[session]) then
        return true
    end

    if inflated_dict[session] then
        return false
    end

    local length = content_length[session]
    if length then
        return #data_dict[session] >= length
    end

    return evt.body ~= nil
end

local function callback(evt)
    if evt.class ~= 'http' then return end
    local empty = not evt.headers or not evt.body or not evt.code
    local raise_error = false
    local session = evt.session
    local self = request_dict[session]

    if not self then return end

    if evt.error and #evt.error > 0 and empty then
        self.set('error', evt.error)
        raise_error = true
    end

    if evt.headers then
        if header_of(evt.headers, 'content-encoding') then
            inflated_dict[session] = true
        end
        local length = header_of(evt.headers, 'content-length')
        if length then
            content_length[session] = tonumber(length)
        end
        self.set('headers', deep_copy.table(evt.headers))
    end

    if evt.code then
        status_dict[session] = tonumber(evt.code)
        self.set('ok', 200 <= tonumber(evt.code) and tonumber(evt.code) < 300)
        self.set('status', evt.code)
    end

    if evt.body then
        data_dict[session] = data_dict[session]..evt.body
    end

    if evt.finished or raise_error or complete(self, session, evt) then
        self.set('body', data_dict[session])
        content_length[session] = nil
        status_dict[session] = nil
        inflated_dict[session] = nil
        request_dict[session] = nil
        data_dict[session] = nil
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