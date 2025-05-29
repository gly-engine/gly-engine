local zeebo_pipeline = require('src/lib/util/pipeline')

--! @defgroup std
--! @{
--! @defgroup storage
--! @{
--! @li empty string is @c nil
--! @li the API is assycronous
--!
--! @pre require @c storage
--!
--! @page storage_get GET (storage)
--! @par Example
--! @code{.java}
--! std.storage.get('name'):as('name'):run()
--! @endcode
--!
--! @page storage_set SET (storage)
--! @par Example
--! @code{.java}
--! std.storage.set('name', data.name):run()
--! @endcode

--! @details updates the current @ref node data.
--! @renamefunc as
--! @hideparam engine
--! @hideparam self
--! @par Example
--! @code{.java}
--! std.storage.get('streak')
--!     :as('streak_loaded', true)
--!     :as('streak', tonumber)
--!     :run()
--! @endcode
local function storage_as(engine, self, name, cast)
    if cast == nil then
        cast = function(v) return v end
    elseif type(cast) ~= 'function' then
        local value = cast
        cast = function() return value end
    end
    local node = engine.current
    self.callbacks[#self.callbacks + 1] = function(value)
        node.data[name] = cast(value)
    end
    return self
end

--! @details result handler.
--! @renamefunc callbacks
--! @hideparam self
--! @par Example
--! @code{.java}
--! std.storage.get('highscore')
--!     :callback(function(value)
--!         data.highscore = std.math.max(data.highscore, tonumber(value))
--!     end)
--!     :run()
--! @endcode
local function storage_callback(self, handler)
    self.callbacks[#self.callbacks + 1] = handler
    return self
end

--! @renamefunc default
--! @hideparam self
--! @endcode
local function storage_default(self, value)
    self.default_value = tostring(value)
    return self
end

--! @}
--! @}

local function storage_command(cmd, std, engine, handlers)
    return function(name, value)
        if type(value) == 'table' and std.json then
            value = std.json.encode(value)
        end
        value = tostring(value or '')

        local self = {
            value = '',
            default_value = '',
            default = storage_default,
            callback = storage_callback,
            as = function(a, b, c) return storage_as(engine, a, b, c) end,
            run = zeebo_pipeline.run,
            callbacks = {}
        }

        self.promise = function() zeebo_pipeline.stop(self) end
        self.resolve = function() zeebo_pipeline.resume(self) end

        self.pipeline = {
            function()
                if cmd == 'set' then
                    handlers.set(name, value or '',  self.promise, self.resolve)
                elseif cmd == 'get' then
                    local save = function(value) self.value = value end
                    handlers.get(name, save, self.promise, self.resolve)
                end
            end,
            function()
                if type(self.value) ~= 'string' or #self.value == 0 then
                    self.value = #self.default_value > 0 and self.default_value or nil
                end
            end,
            function()
               local index = 1
               while index <= #self.callbacks do
                    self.callbacks[index](self.value)
                    index = index + 1
               end
            end
        }

        return self
    end
end

local function install(std, engine, handlers)
    if handlers.install then
        handlers.install(std, engine)
    end
    if not handlers.set or not handlers.get then
        error('missing handlers')
    end
    std.storage = std.storage or {}
    std.storage.set = storage_command('set', std, engine, handlers)
    std.storage.get = storage_command('get', std, engine, handlers)
end

local P = {
    install=install
}

return P
