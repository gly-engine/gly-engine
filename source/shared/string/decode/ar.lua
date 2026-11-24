--! @brief ar reader, the common archive of `.ipk` and `.deb`
--! @details short names are stored as `name/`, longer ones as `/<offset>` into
--! the `//` table, whose entries end in `/\n`. the `/` symbol table is skipped.
local MAGIC = '!<arch>\n'
local HEADER = 60
local TERMINATOR = '`\n'

local function fail(message)
    error(message, 0)
end

local function trim(text)
    return (text:gsub('%s+$', ''))
end

local function long_name(names, offset)
    local name = names:sub(offset + 1):match('^([^/\n]*)/')
    if not name or #name == 0 then
        fail('ar: bad long name at offset '..offset)
    end
    return name
end

--! @short list the members as `{name, body}`, in file order
local function decode(content)
    if content:sub(1, #MAGIC) ~= MAGIC then
        fail('ar: not an ar archive')
    end

    local members = {}
    local names = ''
    local pos = #MAGIC + 1

    while pos <= #content do
        if #content - pos + 1 < HEADER then
            fail('ar: truncated member header')
        end

        local head = content:sub(pos, pos + HEADER - 1)
        if head:sub(59, 60) ~= TERMINATOR then
            fail('ar: bad member header')
        end

        local raw = trim(head:sub(1, 16))
        local size = tonumber(trim(head:sub(49, 58)))
        if not size or size < 0 then
            fail('ar: bad member size')
        end

        local body = content:sub(pos + HEADER, pos + HEADER + size - 1)
        if #body < size then
            fail('ar: truncated member "'..raw..'"')
        end
        pos = pos + HEADER + size + size % 2

        if raw == '//' then
            names = body
        elseif raw ~= '/' then
            local offset = raw:match('^/(%d+)$')
            members[#members + 1] = {
                name = offset and long_name(names, tonumber(offset)) or raw:gsub('/$', ''),
                body = body
            }
        end
    end

    return members
end

return {
    decode = decode
}
