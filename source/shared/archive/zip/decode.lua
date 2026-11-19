local deflate = require('source/third_party/safeteewow_libdeflate')
local hash = require('source/shared/hash/crc32')

local LOCAL_SIGNATURE = 'PK\3\4'
local CENTRAL_SIGNATURE = 'PK\1\2'
local END_SIGNATURE = 'PK\5\6'
local END_SIZE = 22
local MAX_COMMENT = 65535

local function u16(buf, pos)
    local a, b = buf:byte(pos, pos + 1)
    return a + b * 256
end

local function u32(buf, pos)
    local a, b, c, d = buf:byte(pos, pos + 3)
    return a + b * 256 + c * 65536 + d * 2^24
end

local function find_end(buf)
    local last = #buf - END_SIZE + 1
    local first = last - MAX_COMMENT
    if first < 1 then
        first = 1
    end
    for pos = last, first, -1 do
        if buf:sub(pos, pos + 3) == END_SIGNATURE and pos + END_SIZE - 1 + u16(buf, pos + 20) == #buf then
            return pos
        end
    end
    error('zip end of central directory not found')
end

local function files(buf)
    local eocd = find_end(buf)
    local count = u16(buf, eocd + 10)
    local base = eocd - u32(buf, eocd + 12) - u32(buf, eocd + 16)
    local pos = base + u32(buf, eocd + 16)
    local list = {}

    if base < 1 then
        error('invalid zip central directory')
    end

    for index = 1, count do
        if buf:sub(pos, pos + 3) ~= CENTRAL_SIGNATURE then
            error('invalid zip central directory')
        end
        local name_size = u16(buf, pos + 28)
        local header = base + u32(buf, pos + 42)
        if buf:sub(header, header + 3) ~= LOCAL_SIGNATURE then
            error('invalid zip local header')
        end
        list[index] = {
            name = buf:sub(pos + 46, pos + 45 + name_size),
            flags = u16(buf, pos + 8),
            method = u16(buf, pos + 10),
            crc = u32(buf, pos + 16),
            compressed_size = u32(buf, pos + 20),
            size = u32(buf, pos + 24),
            offset = header + 30 + u16(buf, header + 26) + u16(buf, header + 28)
        }
        pos = pos + 46 + name_size + u16(buf, pos + 30) + u16(buf, pos + 32)
    end

    return list
end

local function extract(buf, entry)
    if entry.flags % 2 == 1 then
        error('zip encryption not supported: '..entry.name)
    end
    if entry.size == 0xFFFFFFFF or entry.compressed_size == 0xFFFFFFFF then
        error('zip64 not supported: '..entry.name)
    end

    local data = buf:sub(entry.offset, entry.offset + entry.compressed_size - 1)
    if entry.method == 8 then
        data = deflate:DecompressDeflate(data)
        if not data then
            error('invalid zip deflate data: '..entry.name)
        end
    elseif entry.method ~= 0 then
        error('zip method not supported: '..entry.method)
    end

    if #data ~= entry.size or hash.crc32(data) ~= entry.crc then
        error('zip checksum failed: '..entry.name)
    end
    return data
end

local function find(buf, name)
    local list = files(buf)
    for index = 1, #list do
        if list[index].name == name then
            return extract(buf, list[index])
        end
    end
    return nil
end

local function decode(buf)
    local list = files(buf)
    local members = {}
    for index = 1, #list do
        members[index] = {name = list[index].name, body = extract(buf, list[index])}
    end
    return members
end

return {
    files = files,
    extract = extract,
    find = find,
    decode = decode
}
