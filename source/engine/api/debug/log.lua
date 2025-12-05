local yaml = require('source/shared/string/encode/yaml')

--! @defgroup std
--! @{
--! @defgroup log
--! @{
--! @call code
local levels = { none = 0, fatal = 1, error = 2, warn = 3, info = 4, debug = 5, trace = 6}
--! @call endcode

--! @fakefunc fatal(...)
--! @fakefunc error(...)
--! @fakefunc warn(...)
--! @fakefunc info(...)
--! @fakefunc debug(..)
--! @fakefunc trace(..)
--! @cond
local function printer(engine, printers, func_a, func_b)
    local fn_a = func_a and printers[func_a]
    local fn_b = func_b and printers[func_b]
    local func = fn_a or fn_b or function() end
    local level = levels[func_a] or 7

    return function (...)
        local msgs = {...}
        local count = #msgs

        if level < engine.loglevel then
            local content = ''
            for i = 1, count do
                local v = msgs[i]
                local t = type(v)
                if t == 'table' then
                    content = content..'\n'..yaml.encode(v)..'\n'
                elseif t ~= 'function' then
                    local add_space = i ~= count and i > 1 and content:sub(-1) ~= '\n'
                    local prefix = add_space and ' ' or ''
                    content = content..prefix..tostring(v)
                end
            end
            func(content)
        end
    end
end
--! @endcond

--! @decorator
--! @par Examples
--! @details
--! Adjusts the level of omission of log messages.
--! @code{.java}
--! std.log.level('debug')
--! @endcode
--! @code{.java}
--! std.log.level(5)
--! @endcode
local function level(engine)
    return function(n)
        local lv = levels[n] or (type(n) == 'number' and n) or -1
        if lv < 0 or 6 < lv then
            error('logging level not exist: '..tostring(level)) 
        end
        engine.loglevel = lv
    end
end

--! @decorator
--! @details
--! Restarts log system by redirecting messages to new destinations.
--! @par Example
--! @code{.java}
--! std.log.init({
--!     fatal = function(message) print('[fatal]', message) end,
--!     error = function(message) print('[error]', message) end,
--!     warn  = function(message) print('[warn]',  message) end,
--!     info  = function(message) print('[info]',  message) end,
--!     debug = function(message) print('[debug]', message) end,
--!     trace  = function(message) print('[trace]',  message) end,
--! })
--! @endcode
local function init(std, engine)
    return function(printers)
        std.log.fatal = printer(engine, printers, 'fatal', 'error')
        std.log.error = printer(engine, printers, 'error')
        std.log.warn = printer(engine, printers, 'warn')
        std.log.info = printer(engine, printers, 'info')
        std.log.debug = printer(engine, printers, 'debug', 'info')
        std.log.trace = printer(engine, printers, 'trace', 'info')
    end    
end

--! @}
--! @}

local function install(std, engine, printers)
    std.log = std.log or {}
    std.log.init = init(std, engine)
    std.log.level = level(engine)
    std.log.init(printers)
    std.log.level('debug')
end

local P = {
    install = install
}

return P
