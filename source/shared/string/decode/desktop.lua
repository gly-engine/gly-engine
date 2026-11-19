local escapes = {s = ' ', n = '\n', t = '\t', r = '\r', ['\\'] = '\\', [';'] = '\\;'}

local function unescape(value)
    return (value:gsub('\\(.)', function(c) return escapes[c] or ('\\'..c) end))
end

--! @short decode freedesktop desktop entry (.desktop)
--! @return groups by name, eg: @c out['Desktop Entry'].Name
--! @li localized keys are kept as is, eg: @c Name[pt_BR]
--! @li values are unescaped (@c \\s @c \\n @c \\t @c \\r @c \\\\),
--! lists such as @c Categories stay as @c ; separated strings
--! @note the first group must be @c [Desktop Entry]
local function decode(content)
    content = content:gsub('^\239\187\191', '')
    local result, group, lineno = {}, nil, 0

    for raw in content:gmatch('[^\r\n]+') do
        lineno = lineno + 1
        local line = raw:gsub('^%s+', ''):gsub('%s+$', '')
        if #line > 0 and line:sub(1, 1) ~= '#' then
            local name = line:match('^%[([^%[%]]+)%]$')
            if name then
                if not group and name ~= 'Desktop Entry' then
                    error('is not a desktop entry!', 0)
                end
                if result[name] then
                    error('duplicated group '..name..' at line '..lineno, 0)
                end
                group = {}
                result[name] = group
            else
                local key, value = line:match('^([%w%-]+%[[%w_@%.%-]+%])%s*=%s*(.*)$')
                if not key then
                    key, value = line:match('^([%w%-]+)%s*=%s*(.*)$')
                end
                if not key or not group then
                    error('invalid line '..lineno, 0)
                end
                group[key] = unescape(value)
            end
        end
    end

    if not group then
        error('is not a desktop entry!', 0)
    end

    return result
end

local P = {
    decode = decode
}

return P
