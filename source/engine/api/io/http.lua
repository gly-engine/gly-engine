local zeebo_pipeline = require('src/lib/util/pipeline')

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
--! @li global handler
--! @code{.java}
--! local function http(std, game)
--!     if std.http.error then
--!         print('eg. https is not supported')
--!     end
--!     if std.http.ok then
--!         print('2xx status')
--!     end
--!     if std.http.status > 400 then
--!         print('2xx / 5xx status')
--!     end
--! end
--! @endcode

--! @short json response
--! @hideparam self
--! @brief decode body to table on response
local function json(self)
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

--! @cond
local function request(method, std, engine, protocol)
    local callback_handler = function()
        if std.node then
            std.node.emit(engine.current, 'http')
        elseif engine.current.callbacks.http then
            engine.current.callbacks.http(std, engine.current.data)
        end
    end

    return function (url)
        if protocol.has_callback then
            engine.http_count = engine.http_count + 1
        end

        local json_encode = std.json and std.json.encode
        local json_decode = std.json and std.json.decode
        local http_body = function(self, content) return body(self, content, json_encode) end
        local game = engine.current.data

        local self = {
            -- content
            id = engine.http_count,
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
                if not protocol.force or self.options['noforce'] then return end
                self.url = url:gsub("^[^:]+://", protocol.force.."://")
            end,
            -- eval
            function()
                if protocol.has_callback then engine.http_requests[self.id] = self end
                protocol.handler(self, self.id)
            end,
            -- parse json
            function()
                if self.options['json'] and json_decode and std.http.body then
                    pcall(function()
                        local new_body = json_decode(std.http.body)
                        std.http.body = new_body
                    end)
                end
            end,
            -- callbacks
            function()
                -- global handler
                callback_handler(std, game)
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
                if protocol.has_callback then engine.http_requests[self.id] = nil end
                zeebo_pipeline.reset(self)
            end
        }

        return self
    end
end
--! @endcond

local function install(std, engine, protocol)
    assert(protocol and protocol.handler, 'missing protocol handler')

    if protocol.has_callback then
        engine.http_count = 0
        engine.http_requests = {}
    end

    std.http = std.http or {}
    std.http.get=request('GET', std, engine, protocol)
    std.http.head=request('HEAD', std, engine, protocol)
    std.http.post=request('POST', std, engine, protocol)
    std.http.put=request('PUT', std, engine, protocol)
    std.http.delete=request('DELETE', std, engine, protocol)
    std.http.patch=request('PATCH', std, engine, protocol)
    
    if protocol.install then
        protocol.install(std, engine)
    end
end

local P = {
    install=install
}

return P
