local http_util = require('src/lib/util/http')
local base_url = 'http://localhost:44642/dtv/current-service/ginga/persistent'
local requests = {}
local headers = {
    ['User-Agent'] = http_util.get_user_agent()
}

local function storage_set(key, value, promise, resolve)
    local self = {promise=promise,resolve=resolve}
    local session = tonumber(tostring(self):match("0x(%x+)$"), 16)
    local uri = base_url..'/channel.'..key..'?var-name=channel.'..key
    local body = '{"varValue": "'..value..'"}'

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
    local uri = base_url..'/channel.'..key

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
            local ok, data = pcall(std.json.decode, self.body)
            data = ok and data and data.persistent or data
            data = data and data[1] or data
            data = data and data.value or data
            if ok or evt.finished then
                self.push(data or '')
                self.resolve()
                return
            end
        end
    end
end

local function install(std)
    if not std.json then
        error('require json')
    end
    std.bus.listen_std_engine('ginga', callback)
end

local P = {
    install = install,
    get = storage_get,
    set = storage_set,
}

return P
