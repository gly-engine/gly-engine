local str_url = require('source/shared/string/encode/url')
local str_status = require('source/shared/string/encode/status')
local queue = {}

local function http_handler(self)
    local params = str_url.search_param(self.param_list, self.param_dict)
    local url = self.url .. params
    local method = self.method
    local headers = self.header_dict or {}
    local body = self.body_content

    local threadCode = [[
        local url, method, headers, body, channel = ...
        local meow = require
        local http = meow('socket.http')
        local ltn12 = meow('ltn12')
        local response = {}
        local req = {
            url = url,
            method = method,
            headers = headers,
            source = body and ltn12.source.string(body) or nil,
            sink = ltn12.sink.table(response)
        }
        if body and headers then
            headers["content-length"] = #body
        end
        local ok, status, headers_resp = http.request(req)
        love.thread.getChannel(channel.."ok"):push(ok)
        love.thread.getChannel(channel.."status"):push(status)
        love.thread.getChannel(channel.."body"):push(table.concat(response))
    ]]

    self.promise()
    queue[#queue + 1] = self
    local thread = love.thread.newThread(threadCode)
    thread:start(url, method, headers, body, tostring(self))
end

local function http_callback(self)
    local channel = tostring(self)
    local ok = love.thread.getChannel(channel.."ok"):pop()
    if ok ~= nil then
        local status = love.thread.getChannel(channel.."status"):pop()
        local body = love.thread.getChannel(channel.."body"):pop() or ''
        if not ok then
            self.set('ok', false)
            self.set('error', 'Request failed')
        else
            self.set('ok', str_status.is_ok(status))
            self.set('body', body)
            self.set('status', status)
        end    
        self.resolve()
        return true
    end
    return false
end

local function install(std, engine)
    std.bus.listen('loop', function()
        local index = 1
        while index <= #queue do
            if http_callback(queue[index]) then
                table.remove(queue, index)
            end
            index = index + 1
        end
    end)
end

local P = {
    handler=http_handler,
    install=install
}

return P
