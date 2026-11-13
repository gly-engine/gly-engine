local BLOCK = 512
local MAGIC = 'ustar\0'
local VERSION = '00'
local CHECKSUM_PLACEHOLDER = '        '

local function octal(value, width)
    local text = string.format('%0'..(width - 1)..'o', value)
    if #text > width - 1 then
        error('tar field overflow: '..text)
    end
    return text..'\0'
end

local function text(value, width)
    value = value or ''
    if #value > width then
        error('tar field overflow: '..value)
    end
    return value..string.rep('\0', width - #value)
end

local function to_mode(mode, default)
    if type(mode) == 'string' then
        return tonumber(mode, 8)
    end
    return mode or default
end

local function padding(size)
    return string.rep('\0', (BLOCK - size % BLOCK) % BLOCK)
end

local function split_name(name)
    if #name <= 100 then
        return '', name
    end
    local first = #name - 100
    if first < 2 then
        first = 2
    end
    local last = #name - 1
    if last > 156 then
        last = 156
    end
    for pos = first, last do
        if name:sub(pos, pos) == '/' then
            return name:sub(1, pos - 1), name:sub(pos + 1)
        end
    end
    error('tar name too long: '..name)
end

local function checksum(block)
    local sum = 0
    for index = 1, #block do
        sum = sum + block:byte(index)
    end
    return string.format('%06o', sum)..'\0 '
end

local DEFAULT_MODE = {
    ['0'] = tonumber('644', 8),
    ['2'] = tonumber('777', 8),
    ['5'] = tonumber('755', 8)
}

local function header(member, size, typeflag)
    local prefix, name = split_name(member.name)
    local mode = to_mode(member.mode, DEFAULT_MODE[typeflag])

    local head = text(name, 100)
        ..octal(mode, 8)
        ..octal(member.uid or 0, 8)
        ..octal(member.gid or 0, 8)
        ..octal(size, 12)
        ..octal(member.mtime or 0, 12)

    local tail = typeflag
        ..text(member.link, 100)
        ..MAGIC
        ..VERSION
        ..text(member.uname or 'root', 32)
        ..text(member.gname or 'root', 32)
        ..octal(0, 8)
        ..octal(0, 8)
        ..text(prefix, 155)
        ..string.rep('\0', 12)

    return head..checksum(head..CHECKSUM_PLACEHOLDER..tail)..tail
end

local function kind(member)
    if member.link then
        return '2'
    end
    if member.name:sub(-1) == '/' then
        return '5'
    end
    return '0'
end

local function encode(members)
    local out = {}

    for index = 1, #members do
        local member = members[index]
        if type(member.name) ~= 'string' or #member.name == 0 then
            error('tar member name is required')
        end
        local typeflag = kind(member)
        local body = typeflag == '0' and member.body or ''
        out[#out + 1] = header(member, #body, typeflag)
        out[#out + 1] = body
        out[#out + 1] = padding(#body)
    end

    out[#out + 1] = string.rep('\0', BLOCK * 2)
    return table.concat(out)
end

return {
    encode = encode
}
