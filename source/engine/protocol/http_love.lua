local str_url = require('source/shared/string/encode/url')
local str_status = require('source/shared/string/encode/status')
local queue = {}

local function http_handler(self)
    local params = str_url.search_param(self.param_list, self.param_dict)
    local url = self.url .. params
    local method = self.method
    local headers = self.header_dict or {}
    local body = self.body_content

    if not headers['Accept-Encoding'] then 
        headers['Accept-Encoding'] = 'deflate, gzip'
    end

    if body then
        headers["Content-Length"] = #body
    end

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
        local ok, status, h = http.request(req)
        love.thread.getChannel(channel.."ok"):push(ok)
        love.thread.getChannel(channel.."status"):push(status)
        love.thread.getChannel(channel.."body"):push(table.concat(response))
        love.thread.getChannel(channel.."zip"):push(h and h["content-encoding"] or "")
    ]]

    self.promise()
    queue[#queue + 1] = self
    local thread = love.thread.newThread(threadCode)
    thread:start(url, method, headers, body, tostring(self))
end

local function http_callback(self)
    local reason = nil
    local channel = tostring(self)
    local ok = love.thread.getChannel(channel.."ok"):pop()
    if ok ~= nil then
        local status = love.thread.getChannel(channel.."status"):pop()
        local body = love.thread.getChannel(channel.."body"):pop() or ''
        local zip = love.thread.getChannel(channel.."zip"):pop()

        if zip and #zip > 0 then
            if not pcall(function()
                body = love.data.decompress('string', zip == 'gzip' and 'gzip' or 'zlib', body)
            end) then
                ok, reason = false, 'Failed unzip'
            end
        end

        if not ok then
            self.set('ok', false)
            self.set('error', reason or 'Request failed')
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
