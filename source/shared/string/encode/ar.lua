local MAGIC = '!<arch>\n'
local TERMINATOR = '`\n'
local DEFAULT_MODE = '100644'

local function field(value, width)
    local text = tostring(value)
    if #text > width then
        error('ar field overflow: '..text)
    end
    return text..string.rep(' ', width - #text)
end

local function octal(mode, default)
    if type(mode) == 'number' then
        return string.format('%o', mode)
    end
    return mode or default
end

local function padding(size)
    if size % 2 == 1 then
        return '\n'
    end
    return ''
end

local function header(name, size, member)
    return field(name, 16)
        ..field(member.mtime or 0, 12)
        ..field(member.uid or 0, 6)
        ..field(member.gid or 0, 6)
        ..field(octal(member.mode, DEFAULT_MODE), 8)
        ..field(size, 10)
        ..TERMINATOR
end

local function names_table(members)
    local names = {}
    local entries = {}
    local offset = 0

    for index = 1, #members do
        local name = members[index].name
        if type(name) ~= 'string' or #name == 0 then
            error('ar member name is required')
        end
        if name:find('[/\n]') then
            error('invalid ar member name: '..name)
        end
        if #name > 15 then
            local entry = name..'/\n'
            names[index] = '/'..offset
            entries[#entries + 1] = entry
            offset = offset + #entry
        else
            names[index] = name..'/'
        end
    end

    return names, table.concat(entries)
end

local function encode(members)
    local out = {MAGIC}
    local names, long_names = names_table(members)

    if #long_names > 0 then
        out[#out + 1] = field('//', 48)..field(#long_names, 10)..TERMINATOR
        out[#out + 1] = long_names
        out[#out + 1] = padding(#long_names)
    end

    for index = 1, #members do
        local member = members[index]
        local body = member.body or ''
        out[#out + 1] = header(names[index], #body, member)
        out[#out + 1] = body
        out[#out + 1] = padding(#body)
    end

    return table.concat(out)
end

return {
    encode = encode
}
