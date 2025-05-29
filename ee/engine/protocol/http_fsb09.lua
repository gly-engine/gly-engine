--! @short HTTP ginga module
--! 
--! @li @b specification: https://www.rfc-editor.org/rfc/rfc2616
--!
--! @par Compare
--! | feature/support | this module     | manoel campos  |
--! | :-              | :-:             | :-:            |
--! | Samsung TVs     | yes             | no             |
--! | Redirect 3xx    | yes             | no             |
--! | HTTPS protocol  | handler error   | no             |
--! | Timeout request | yes             | no             |
--! | DNS Resolving   | yes             | no             |
--! | multi-request   | yes, event loop | yes, corotines |
--!
--! @note @b Samsung Tvs have connections blocked when host is not cached in DNS
--!
--! @par Finite State Machine
--! @startuml
--! hide empty description
--! state 0 as "no requests"
--! state 1 as "DNS resolving": first request
--! state 2 as "DNS disabled"
--! state 3 as "DNS Idle"
--! state 4 as "DNS resolving"
--! 
--! [*] -> 0
--! 0 -> 1
--! 1 -> 2
--! 1 -> 3
--! 3 -> 4
--! 4 -> 3
--! 2 -> [*]
--! @enduml
--!
--! @par Contexts
--! @startjson
--! {
--!    "resolve": "8.8.8.8",
--!    "by_dns": {
--!       "google.com": "8.8.8.8"
--!    },
--!    "by_host": {
--!       "8.8.8.8": [
--!         {
--!          "url": "google.com/search?q=pudim.com.br" 
--!         }
--!       ],
--!       "pudim.com.br": [
--!         {
--!          "url": "pudim.com.br/"
--!         }
--!       ],
--!       "example.com": [
--!         {
--!          "url": "example.com/foo"
--!         },
--!         {
--!          "url": "example.com/bar"
--!         }
--!       ]
--!    },
--!    "by_connection": {
--!      "connector.id.1" : {
--!         "url": "example.com/zig"
--!      },
--!      "connector.id.2" : {
--!         "url": "example.com/zag"
--!      }
--!    }
--! }
--! @endjson
local http_util = require('src/lib/util/http')
local lua_util = require('src/lib/util/lua')

--! @todo refactor this
local application_internal
application_internal = {}

--! @cond
local function http_connect(self)
    local params = http_util.url_search_param(self.param_list, self.param_dict)
    local request = http_util.create_request(self.method, self.p_uri..params)
        .add_imutable_header('Host', self.p_host)
        .add_imutable_header('Cache-Control', 'max-age=0')
        .add_mutable_header('Accept', '*/*')
        .add_mutable_header('Accept-Charset', 'utf-8', lua_util.has_support_utf8())
        .add_mutable_header('Accept-Charset', 'windows-1252, cp1252')
        .add_mutable_header('User-Agent', http_util.get_user_agent())
        .add_custom_headers(self.header_list, self.header_dict)
        .add_imutable_header('Content-Length', tostring(#self.body_content), #self.body_content > 0)
        .add_imutable_header('Connection', 'close')
        .add_body_content(self.body_content)
        .to_http_protocol()

    event.post({
        class      = 'tcp',
        type       = 'data',
        connection = self.evt.connection,
        value      = request,
    })
end
--! @endcond

--! @cond
local function http_connect_dns(self)
    if self.p_host == self.evt.host then -- behavior when mixing ip and domain???
        application_internal.http.dns_state = 2
    else
        application_internal.http.context.dns(self)
        application_internal.http.dns_state = 3
    end
    if tostring(self.evt.connection) ~= '0' then
        event.post({
            class      = 'tcp',
            type       = 'disconnect',
            connection =  self.evt.connection,
        })
    end
end
--! @endcond

--! @cond
local function http_headers(self)
    self.p_header = self.p_data:sub(1, self.p_header_pos -1)
    self.p_status = tonumber(self.p_header:match('^HTTP/%d.%d (%d+) %w*'))
    self.p_content_size = tonumber(self.p_header:match('Content%-Length: (%d+)') or 0)
end
--! @endcond

--! @cond
local function http_redirect(self)
    local protocol, location = self.p_header:match('Location: (%w+)://([^%s]*)')
    local url, uri = (location or self.url):match('^([^/]+)(.*)$')
    local host, port_str = url:match("^(.-):?(%d*)$")
    local redirects =  self.p_redirects + 1
    local port = tonumber(port_str and #port_str > 0 and port_str or 80)
    
    if protocol == 'https' and self.p_host == url then
        self.evt.error = 'HTTPS is not supported!'
        application_internal.http.callbacks.http_error(self)
    elseif self.p_redirects > 5 then
        self.evt.error = 'Too Many Redirects!'
        application_internal.http.callbacks.http_error(self)
    else
        local index = #application_internal.http.queue + 1

        if tostring(self.evt.connection) ~= '0' then
            event.post({
                class      = 'tcp',
                type       = 'disconnect',
                connection =  self.evt.connection,
            })
        end

        application_internal.http.context.remove(self.evt)
        application_internal.http.callbacks.http_clear(self)

        self.p_url = url
        self.p_uri = uri or '/'
        self.p_ip = host
        self.p_host = host
        self.p_port = port
        self.p_data = ''
        self.p_redirects = redirects

        application_internal.http.queue[index] = self
    end
end
--! @endcond

--! @cond
local function http_error(self)
    if self and self.set and self.resolve then
        self.set('ok', false)
        self.set('error', self.evt and self.evt.error or 'unknown error')
        self.resolve()
    end
end
--! @endcond

--! @cond
local function http_data_fast(self)
    local evt = self.evt
    local status = self.evt.value:match('^HTTP/%d.%d (%d+) %w*')
    if not status then
        self.evt = {error = self.evt.value}
        application_internal.http.callbacks.http_error(self)
    else
        self.p_status = tonumber(status)
        application_internal.http.callbacks.http_resolve(self)
    end
    event.post({
        class      = 'tcp',
        type       = 'disconnect',
        connection =  evt.connection,
    })
end
--! @endcond

--! @cond
local function http_data(self)
    self.p_data = self.p_data..self.evt.value

    if not self.p_header_pos then
        self.p_header_pos = self.p_data:find('\r\n\r\n')
        if self.p_header_pos then
            application_internal.http.callbacks.http_headers(self)
        end
        if http_util.is_redirect(self.p_status) then
            application_internal.http.callbacks.http_redirect(self)
            return
        end
    end

    if self.p_header_pos and (#self.p_data - self.p_header_pos) >= self.p_content_size then
        local evt = self.evt
        application_internal.http.context.remove(self.evt)
        application_internal.http.callbacks.http_resolve(self)
        ---! @bug LG 2024 not working close contection with ID 0
        if tostring(evt.connection) ~= '0' then
            event.post({
                class      = 'tcp',
                type       = 'disconnect',
                connection =  evt.connection,
            })
        end
    end
end
--! @endcond

--! @cond
local function http_resolve(self)
    local body = ''
    if self.speed ~= '_fast' then
        body = self.p_data:sub(self.p_header_pos + 4, #self.p_data)
    end
    self.set('ok', http_util.is_ok(self.p_status))
    self.set('status', self.p_status)
    self.set('body', body)
    application_internal.http.callbacks.http_clear(self)
    self.resolve()
end
--! @endcond

--! @cond
local function http_clear(self)
    self.evt = nil
    self.p_url = nil
    self.p_uri = nil
    self.p_host = nil
    self.p_port = nil
    self.p_status = nil
    self.p_content_size = nil
    self.p_header = nil
    self.p_header_pos = nil
    self.p_data = nil
    self.p_redirects = nil
end
--! @endcond

--! @short create request
local function http_handler(self)
    local protocol, location = self.url:match('(%w*)://?(.*)')
    local url, uri = (location or self.url):match('^([^/]+)(.*)$')
    local host, port_str = url:match("^([%w%.]+)([:0-9]*)$") 
    local port = tonumber((port_str and #port_str > 0 and port_str:sub(2, #port_str)) or 80)

    self.p_url = url
    self.p_uri = uri or '/'
    self.p_ip = host
    self.p_host = host
    self.p_port = port
    self.p_data = ''
    self.p_redirects = 0

    if protocol ~= 'http' and location then
        self.evt = { error = 'HTTPS is not supported!' }
        application_internal.http.callbacks.http_error(self)
    else
        local index = #application_internal.http.queue + 1
        application_internal.http.queue[index] = self
        self.promise()
    end
end

--! @cond
local function context_dns(self, contexts)
    if self.p_host and self.p_ip and self.p_host ~= self.p_ip then
        contexts.by_dns[self.p_host] = self.p_ip
        return true
    elseif contexts.by_dns[self.p_host] then
        self.p_ip = contexts.by_dns[self.p_host]
        return true
    else
        contexts.dns_resolve = self
        return false
    end
end
--! @endcond

--! @cond
local function context_push(self, contexts)
    local host = self.p_ip
    if not contexts.by_host[host] then
        contexts.by_host[host] = {}
    end
    local index = #contexts.by_host[host] + 1
    contexts.by_host[host][index] = self
end
--! @endcond

--! @cond
local function context_pull(evt, contexts)
    local self = nil
    local connection = evt.connection
    local host = (evt.host and contexts.by_dns[evt.dns]) or evt.host
    local index = host and contexts.by_host[host] and #contexts.by_host[host]
    
    if host and contexts.dns_resolve then
        self = {
            speed = '_dns',
            type = 'connect',
            p_host = contexts.dns_resolve.p_host,
            p_ip = host
        }
        contexts.dns_resolve = nil
    elseif evt.type == 'connect' and host and index and contexts.by_host[host][index] then
        self = contexts.by_host[host][index]
        if connection then
            contexts.by_connection[connection] = self
            contexts.by_host[host][index] = nil
        end
    elseif connection and contexts.by_connection[connection] then
        self = contexts.by_connection[connection]  
    end

    if self then
        self.evt = evt
        if evt.error then
            self.speed='_error'
            if connection and contexts.by_connection[connection] then
                contexts.by_connection[connection] = nil
            end
            if host and index and contexts.by_host[host][index] then
                contexts.by_host[host][index] = nil
            end
        end
    end

    return self
end
--! @endcond

--! @cond
local function context_remove(evt, contexts)
    local connection = evt.connection

    if connection then
        contexts.by_connection[connection] = nil
    end
end
--! @endcond

--! @short dequeue request
--! @param [in] std
--! @param [in] game
--! @param [in, out] application
--! @brief This code may seem confusing, but it was the simplest I thought,
--! analyze the finite state machine to understand better.
local function fixed_loop()
    local state = application_internal.http.dns_state
    local index = #application_internal.http.queue
    while index >= 1 and state ~= 1 and state ~= 4 do
        local self = application_internal.http.queue[index]

        if state == 0 then
            application_internal.http.context.dns(self)
            state = 1
        elseif state == 2 then
            application_internal.http.context.push(self)
            application_internal.http.queue[index] = nil
        elseif state == 3 then
            if application_internal.http.context.dns(self) then
                application_internal.http.context.push(self)
                application_internal.http.queue[index] = nil
            else
                state = 4
            end
        end

        event.post({
            class = 'tcp',
            type  = 'connect',
            host  = self.p_ip,
            port  = self.p_port
        })

        application_internal.http.dns_state = state
        index = index - 1
    end
end

--! @short resolve request
local function event_loop(evt)
    if evt.class ~= 'tcp' then return end
    if evt.type == 'disconnect' then return end
    local self = application_internal.http.context.pull(evt)

    local value = tostring(evt.value)
    local _debug = evt.type..' '..tostring(evt.host)..' '..tostring(evt.connection)..' '..value:gsub('\n', ''):sub(1, 90)

    if self and self.evt and self.evt.type then
        local index = 'http_'..self.evt.type..self.speed
        local callback = application_internal.http.callbacks[index]
        pcall(callback, self)
    end
end

local function install(std, engine)
    local contexts = {
        by_dns={},
        by_host={},
        by_connection={}
    }

    application_internal.http = {}
    application_internal.http.dns_state = 0
    application_internal.http.queue = {}
    application_internal.http.context = {
        dns = function(self) return context_dns(self, contexts) end,
        push = function(self) context_push(self, contexts) end,
        pull = function(evt) return context_pull(evt, contexts) end,
        remove = function (evt) context_remove(evt, contexts) end
    }

    application_internal.http.callbacks = {
        -- dns 
        http_connect_dns=http_connect_dns,
        -- error
        http_connect_error=http_error,
        http_data_error=http_error,
        -- fast
        http_connect_fast=http_connect,
        http_data_fast=http_data_fast,
        -- http
        http_connect=http_connect,
        http_data=http_data,
        -- extra
        http_redirect=http_redirect,
        http_headers=http_headers,
        http_resolve=http_resolve,
        http_error=http_error,
        http_clear=http_clear,
    }

    std.bus.listen('loop', fixed_loop)
    std.bus.listen('ginga', event_loop)

    return {
        http=application_internal.http
    }
end

local P = {
    force = 'http',
    util = http_util,
    handler = http_handler,
    install = install
}

return P
