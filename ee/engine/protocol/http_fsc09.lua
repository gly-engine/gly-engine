local http_util = require('src/lib/util/http')
local ginga_support = require('ee/lib/util/support')
local content_length = {}
local request_dict = {}
local data_dict = {}

local function handler(self)
    local uri = self.url..http_util.url_search_param(self.param_list, self.param_dict)
    local session = tonumber(tostring(self):match("0x(%x+)$"), 16)
    local allow_body = self.method ~= 'GET' and self.method ~= 'HEAD'
    local method = string.lower(self.method)
    local body = allow_body and self.body
    local headers = self.header_dict

    if not headers['User-Agent'] then
        headers['User-Agent'] = http_util.get_user_agent()
    end

    data_dict[session] = ''
    request_dict[session] = self
    content_length[session] = -1

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

    if not self then return end

    if evt.error and #evt.error > 0 and empty then
        self.set('error', evt.error)
        raise_error = true
    end

    if evt.headers then
        if evt.headers['Content-Length'] then
            content_length[session] = tonumber(evt.headers['Content-Length'])
        end
    end

    if evt.code then
        self.set('ok', http_util.is_ok(evt.code))
        self.set('status', evt.code)
    end

    if evt.body then
        data_dict[session] = data_dict[session]..evt.body
    end

    if evt.finished or raise_error or content_length[session] <= #data_dict[session] then
        self.set('body', data_dict[session])
        content_length[session] = nil
        request_dict[session] = nil
        data_dict[session] = nil
        self.resolve()
    end
end

local function install(std)    
    if not ginga_support.class('http') then
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
