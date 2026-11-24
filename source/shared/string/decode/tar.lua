--! @brief ustar reader, the inside of `control.tar.gz` and `data.tar.gz`
local math = require('math')

local BLOCK = 512
local CHECKSUM_AT = 149
local CHECKSUM_SIZE = 8

local function fail(message)
    error(message, 0)
end

local function text(field)
    return (field:gsub('%z.*$', ''))
end

local function octal(field)
    local digits = text(field):gsub('^%s+', ''):gsub('%s+$', '')
    if #digits == 0 then
        return 0
    end
    return tonumber(digits, 8) or fail('tar: bad numeric field "'..digits..'"')
end

--! @short the stored checksum is computed with its own field read as spaces
local function checksum(block)
    local sum = 0
    for index = 1, BLOCK do
        local byte = block:byte(index)
        if index >= CHECKSUM_AT and index < CHECKSUM_AT + CHECKSUM_SIZE then
            byte = 32
        end
        sum = sum + byte
    end
    return sum
end

--! @short list the entries as `{name, body, mode, directory}`, in file order
--! @details `name` keeps the archive spelling, `./foo` and `foo` both survive
local function decode(content)
    local entries = {}
    local empty = string.rep('\0', BLOCK)
    local pos = 1

    while pos + BLOCK - 1 <= #content do
        local block = content:sub(pos, pos + BLOCK - 1)
        if block == empty then
            break
        end

        local name = text(block:sub(1, 100))
        local size = octal(block:sub(125, 136))
        local typeflag = block:sub(157, 157)
        local prefix = text(block:sub(346, 500))

        if checksum(block) ~= octal(block:sub(CHECKSUM_AT, CHECKSUM_AT + CHECKSUM_SIZE - 1)) then
            fail('tar: bad checksum for "'..name..'"')
        end
        if #prefix > 0 then
            name = prefix..'/'..name
        end

        pos = pos + BLOCK
        local body = content:sub(pos, pos + size - 1)
        if #body < size then
            fail('tar: truncated "'..name..'"')
        end
        pos = pos + size + (BLOCK - size % BLOCK) % BLOCK

        local directory = typeflag == '5' or name:sub(-1) == '/'
        entries[#entries + 1] = {
            name = name,
            body = not directory and body or nil,
            mode = octal(block:sub(101, 108)),
            directory = directory,
            typeflag = typeflag
        }
    end

    return entries
end

return {
    decode = decode
}
