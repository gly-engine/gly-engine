local zeebo_pipeline = require('source/shared/functional/pipeline')

--! @defgroup std
--! @{
--! @defgroup http
--! @pre require @c http
--! @{
--!
--! @page http_get GET
--! 
--! @code{.java}
--! std.http.get('https://api.github.com/zen')
--!     :run()
--! @endcode
--!
--! @page http_post POST
--! 
--! @code{.java}
--! std.http.post('https://example.com.br'):json()
--!     :header('Authorization', 'Basic dXN1YXJpb3NlY3JldG86c2VuaGFzZWNyZXRh')
--!     :param('telefone', '188')
--!     :body({
--!         user = 'Joao',
--!         message = 'Te ligam!'
--!     })
--!     :run()
--! @endcode
--!
--! @page http_request Http requests
--! 
--! @li @b std.http.get
--! @li @b std.http.head
--! @li @b std.http.post
--! @li @b std.http.put
--! @li @b std.http.delete
--! @li @b std.http.patch
--! 
--! @page http_response Http responses
--!
--! @li local handlers
--! @code
--! std.http.get('http://pudim.com.br')
--!     :success(function()
--!         print('2xx callback')
--!     end)
--!     :failed(function()
--!         print('4xx / 5xx callback')
--!     end)
--!     :error(function()
--!         print('eg. to many redirects')
--!     end)
--!     :run()
--! @endcode

--! @short json response
--! @hideparam self
--! @brief decode body to table on response
local function json(self)
    print('std.http.get():json() is deprecated.')
    self.options['json'] = true
    return self
end

--! @short not force protocol
--! @hideparam self
--! @brief By default, requests follow the protocol (HTTP or HTTPS) based on their origin (e.g., HTML5).
--! This setting allows opting out of that behavior and disabling automatic protocol enforcement.
local function noforce(self)
    self.options['noforce'] = true
    return self
end

--! @short reduced response
--! @hideparam self
--! @brief disconnect when receiving status
local function fast(self)
    self.speed = '_fast'
    return self
end

--! @hideparam self
local function param(self, name, value)
    local index = #self.param_list + 1
    self.param_list[index] = tostring(name)
    self.param_dict[name] = tostring(value)
    return self
end

--! @hideparam self
--! @par Eaxmaple
--! @code{.java}
--! std.http.post('http://example.com/secret-ednpoint')
--!     :header('Authorization', 'Bearer c3VwZXIgc2VjcmV0IHRva2Vu')
--!     :run()
--! @endcode
local function header(self, name, value)
    local index = #self.header_list + 1
    self.header_list[index] = tostring(name)
    self.header_dict[name] = tostring(value)
    return self
end

--! @hideparam self
--! @hideparam json_encode
--! @pre you can directly place a @b table in your body which will automatically be encoded and passed the header `Content-Type: application/json`,
--! but for this you previously need to require @c json
--! 
--! @par Examples
--! @code{.java}
--! std.http.post('http://example.com/plain-text'):body('foo is bar'):run()
--! @endcode
--! @code{.java}
--! std.http.post('http://example.com/json-object'):body({foo = bar}):run()
--! @endcode
local function body(self, content, json_encode)
    if type(content) == 'table' then
        header(self, 'Content-Type', 'application/json')
        content = json_encode(content)
    end
    self.body_content=content
    return self
end

--! @hideparam self
local function success(self, handler_func)
    self.success_handler = handler_func
    return self
end

--! @hideparam self
local function failed(self, handler_func)
    self.failed_handler = handler_func
    return self
end

--! @hideparam self
--! @renamefunc error
local function http_error(self, handler_func)
    self.error_handler = handler_func
    return self
end

--! @}
--! @}

local function off(self, name, func)
    local count = 1
    local list = self.handlers[name] or {}
    for i = 1, #list do
        if list[i] ~= func then
            list[count] = list[i]
            count = count + 1
        end     
    end
    for i = count, #list do
        list[i] = nil
    end
    self.handlers[name] = list
    return self
end

local function on(self, name, func)
    off(self, name, func)
    local list = self.handlers[name]
    list[#list + 1] = func
    return self
end

local function websocket_create(request, engine, protocol)
    return {
        id = request.id,
        on = function(self, name, func)
            on(request, name, func)
        end,
        off = function(self, name, func)
            off(request, name, func)
        end,
        send = function(self, data)
            if not engine.http[self.id] then return false end
            return protocol.sock(self.id, 1, data) 
        end,
        close = function(self)
            protocol.sock(self.id, 2)
            engine.http[self.id] = nil
        end,
        is_connected = function(self)
            if not engine.http[self.id] then return false end
            return protocol.sock(self.id, 3)
        end
    }
end

--! @cond
local function websocket_request(std, engine, protocol)
    return function(url, upgrade)
        local self = {
            url = url,
            method = 'SOCK',
            upgrade = upgrade,
            header_list = {},
            header_dict = {},
            param_list = {},
            param_dict = {},
            handlers = {},
            -- functions
            on = on,
            off = off,
            param = param,
            header = header,
            run = zeebo_pipeline.run,
        }

        self.promise = function()
            zeebo_pipeline.stop(self)
        end

        self.resolve = function()
            zeebo_pipeline.resume(self)
        end
        
        self.set = function (key, value)
            std.http[key] = value
        end

        self:on('disconnect', function()
            if self.id then engine.http[self.id] = nil end
        end)

        self.pipeline = {
            function()
                self.id = tonumber(tostring({}):gsub('0x', ''):match('^table: (%w+)$'), 16)
                engine.http[self.id] = self
            end,
            function()
                protocol.handler(self, self.id)
            end,
            function()
                if std.http.ok then
                    local sock = websocket_create(self, engine, protocol)
                    for _, h in ipairs(self.handlers.open or {}) do h(sock) end
                else
                    if not std.http.error then self.set('error', 'core not upgrade to ws') end
                    for _, h in ipairs(self.handlers.error or {}) do h(std.http.error) end
                    engine.http[self.id] = nil
                end
            end,
            function()
                std.http.ok = nil
                std.http.error = nil
                zeebo_pipeline.reset(self)
            end
        }

        return self
    end
end

local function request(method, std, engine, protocol)
    return function (url)
        local json_encode = std.json and std.json.encode
        local json_decode = std.json and std.json.decode
        local http_body = function(self, content) return body(self, content, json_encode) end
        local game = engine.current.data

        local self = {
            url = url,
            speed = '',
            options = {},
            method = method,
            body_content = '',
            header_list = {},
            header_dict = {},
            param_list = {},
            param_dict = {},
            success_handler = function (std, game) end,
            failed_handler = function (std, game) end,
            error_handler = function (std, game) end,
            -- functions
            fast = fast,
            json = json,
            noforce = noforce,
            body = http_body,
            param = param,
            header = header,
            success = success,
            failed = failed,
            error = http_error,
            run = zeebo_pipeline.run,
        }

        self.promise = function()
            zeebo_pipeline.stop(self)
        end

        self.resolve = function()
            zeebo_pipeline.resume(self)
        end

        self.set = function (key, value)
            std.http[key] = value
        end

        self.pipeline = {
            -- prepare
            function()
                self.id = tonumber(tostring({}):gsub('0x', ''):match('^table: (%w+)$'), 16)
                engine.http[self.id] = self
                if protocol.force and not self.options['noforce'] then
                    self.url = url:gsub("^[^:]+://", protocol.force.."://")
                end
            end,
            -- eval
            function()
                protocol.handler(self, self.id)
            end,
            -- parsers
            function()
                if self.options['json'] and json_decode and std.http.body then
                    local ok, err = pcall(function()
                        local new_body = json_decode(std.http.body)
                        std.http.body = new_body
                    end)
                    if not ok then
                        self.set('ok', false)
                        self.set('error', err)
                    end
                end

                local lower_header = {}
                for k, v in pairs(std.http.headers or {}) do
                    lower_header[string.lower(k)] = v
                end
                std.http.headers = lower_header
            end,
            -- callbacks
            function()
                -- local handlers
                if std.http.ok then
                    self.success_handler(std, game)
                elseif std.http.error then
                    self.error_handler(std, game)
                elseif not std.http.status then
                    self.set('error', 'missing protocol response')
                    self.error_handler(std, game)
                else
                    self.failed_handler(std, game)
                end
            end,
            -- clean http
            function ()
                std.http.ok = nil
                std.http.body = nil
                std.http.error = nil
                std.http.status = nil
                std.http.body_is_table = nil
            end,
            -- reset request
            function()
                engine.http[self.id] = nil
                zeebo_pipeline.reset(self)
            end
        }

        return self
    end
end
--! @endcond

local function install(std, engine, protocol)
    assert(protocol and protocol.handler, 'missing protocol handler')

    engine.http = {}
    std.http = std.http or {}
    std.http.get=request('GET', std, engine, protocol)
    std.http.head=request('HEAD', std, engine, protocol)
    std.http.post=request('POST', std, engine, protocol)
    std.http.put=request('PUT', std, engine, protocol)
    std.http.delete=request('DELETE', std, engine, protocol)
    std.http.patch=request('PATCH', std, engine, protocol)

    if protocol.sock then
        std.http.connect = websocket_request(std, engine, protocol)
    end
    
    if protocol.install then
        protocol.install(std, engine)
    end
end

local P = {
    install=install
}

return P
