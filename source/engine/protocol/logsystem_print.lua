local function printer(logtype)
    return function(message)
        if print then print('['..logtype..'] '..tostring(message)) end
    end
end

local P = {
    fatal = printer('fatal'),
    error = printer('error'),
    warn = printer('warn'),
    info = printer('info'),
    debug = printer('debug')
}

return P
