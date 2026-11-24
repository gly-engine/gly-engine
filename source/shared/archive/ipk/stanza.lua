--! @brief the `Field: value` control stanza, shared by the ipk encode and decode
--! @details one package per file, continuation lines start with a space or tab
local function fail(message)
    error(message, 0)
end

local function trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

--! @short parse the control into `{key, value}` fields, in file order
local function parse(control)
    local fields = {}
    local last = nil
    local ended = false

    for line in (control..'\n'):gmatch('([^\n]*)\n') do
        line = line:gsub('\r$', '')
        if trim(line) == '' then
            ended = #fields > 0
        elseif ended then
            fail('control: only one package per file, found a blank line between fields')
        elseif line:find('^[ \t]') then
            if not last then
                fail('control: line "'..line..'" continues no field')
            end
            local value = trim(line)
            if #value > 0 then
                last.value = #last.value > 0 and last.value..'\n'..value or value
            end
        else
            local key, value = line:match('^([^:]*):(.*)$')
            if not key or trim(key) == '' then
                fail('control: line "'..line..'" is not "Field: value"')
            end
            last = {key = trim(key), value = trim(value)}
            fields[#fields + 1] = last
        end
    end

    return fields
end

local function write(fields)
    local out = {}
    for _, field in ipairs(fields) do
        local first = true
        for line in (field.value..'\n'):gmatch('([^\n]*)\n') do
            out[#out + 1] = first and (field.key..': '..line..'\n') or (' '..line..'\n')
            first = false
        end
    end
    return table.concat(out)
end

local function get(fields, key)
    for _, field in ipairs(fields) do
        if field.key == key then
            return field.value
        end
    end
end

local function without(fields, keys)
    local out = {}
    for _, field in ipairs(fields) do
        if not keys[field.key] then
            out[#out + 1] = field
        end
    end
    return out
end

return {
    fail = fail,
    parse = parse,
    write = write,
    get = get,
    without = without
}
