local util_decorator = require('src/lib/util/decorator')

--! @defgroup std
--! @{
--! @defgroup log
--! @{
--! @call code
local logging_types = {
    'none', 'fatal', 'error', 'warn', 'debug', 'info'
}
--! @call endcode

--! @fakefunc fatal(message)
--! @fakefunc error(message)
--! @fakefunc warn(message)
--! @fakefunc debug(message)
--! @fakefunc info(message)

--! @hideparam engine
--! @hideparam lpf
--! @hideparam lpn

--! @par Examples
--! @details
--! Adjusts the level of omission of log messages.
--! @code{.java}
--! std.log.level(std.log.error)
--! @endcode
--! @code{.java}
--! std.log.level('error')
--! @endcode
--! @code{.java}
--! std.log.level(3)
--! @endcode
local function level(engine, lpf, lpn, level)
    local l = lpf[level] or lpn[level] or level
    if type(l) ~= 'number' or l <= 0 or l > #logging_types then
        error('logging level not exist: '..tostring(level)) 
    end
    engine.loglevel = l
end

--! @hideparam std
--! @hideparam engine
--! @details
--! Restarts log system by redirecting messages to new destinations.
--! @par Example
--! @code{.java}
--! std.log.init({
--!     fatal = function(message) print('[fatal]', message) end,
--!     error = function(message) print('[error]', message) end,
--!     warn  = function(message) print('[warn]',  message) end,
--!     debug = function(message) print('[debug]', message) end,
--!     info  = function(message) print('[info]',  message) end
--! })
--! @endcode
local function init(std, engine, printers)
    local index = 1
    local level_per_func = {}
    local level_per_name = {}
    while index <= #logging_types do
        local ltype = logging_types[index]
        local lfunc = function() end
        if index > 1 and printers[ltype] then
            lfunc = (function (level)
                return function(message)
                    if engine.loglevel >= level then
                        printers[ltype](message)
                    end
                end
            end)(index - 1)
        end
        level_per_func[lfunc] = index - 1
        level_per_name[ltype] = index - 1
        std.log[ltype] = lfunc
        index = index + 1
    end
    std.log.level = util_decorator.prefix3(engine, level_per_func, level_per_name, level)
end

--! @}
--! @}

local function install(std, engine, printers)
    std.log = std.log or {}
    engine.loglevel = #logging_types
    std.log.init = util_decorator.prefix2(std, engine, init)
    std.log.init(printers)
end

local P = {
    install = install
}

return P
