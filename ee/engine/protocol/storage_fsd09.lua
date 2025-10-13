local user_agent = require('source/agent')
local base_url = 'http://localhost:44642/dtv/current-service/ginga/persistent'
local requests = {}
local headers = {
    ['User-Agent'] = user_agent
}

local function encode_bytes(str)
    return (str:gsub('.', function(c)
        return string.format('%02x', string.byte(c))
    end))
end

local function decode_bytes(hexstr)
    return (hexstr:gsub('(%x%x)', function(h)
        local n = tonumber(h, 16)
        return n and string.char(n) or ''
    end))
end

local function storage_set(key, value, promise, resolve)
    local self = {promise=promise,resolve=resolve}
    local session = tonumber(tostring(self):match("0x(%x+)$"), 16)
    local uri = base_url..'/channel.'..key..'?var-name=channel.'..key
    local body = '{"varValue": "'..encode_bytes(value)..'"}'

    requests[session] = self

    self.promise()
    event.post({
        class = 'http',
        type = 'request',
        method = 'post',
        uri = uri,
        body = body,
        headers = headers,
        session = session
    })
end

local function storage_get(key, push, promise, resolve)
    local self = {push=push,promise=promise,resolve=resolve,body=''}
    local session = tonumber(tostring(self):match("0x(%x+)$"), 16)
    local uri = base_url..'?var-name=channel.'..key

    requests[session] = self

    self.promise()
    event.post({
        class = 'http',
        type = 'request',
        method = 'get',
        uri = uri,
        headers = headers,
        session = session
    })
end

local function callback(std, engine, evt)
    if evt.class ~= 'http' or not evt.session then return end
    
    local self = requests[evt.session]

    if self then
        if not self.body then
            requests[evt.session] = nil
            self.resolve()
            return
        end

        if evt.body then
            self.body = self.body..evt.body
        end

        if (evt.error and (not evt.body or not evt.code)) or evt.code ~= 200 then
            requests[evt.session] = nil
            self.resolve()
            return
        end

        if evt.finished or evt.code == 200 then
            requests[evt.session] = nil
            self.push(decode_bytes(self.body))
            self.resolve()
        end
    end
end

local function install(std, engine)
    if tostring(engine.envs.ginga_fsd_09) ~= 'true' then
        error('old device!')
    end
    std.bus.listen_std_engine('ginga', callback)
end

local P = {
    install = install,
    get = storage_get,
    set = storage_set,
}

return P
