local math = require('math')
local deflate = require('source/third_party/safeteewow_libdeflate')
local hash = require('source/shared/hash/crc32')

local floor = math.floor

local LOCAL_SIGNATURE = 'PK\3\4'
local CENTRAL_SIGNATURE = 'PK\1\2'
local END_SIGNATURE = 'PK\5\6'
local DOS_DATE = 33
local DOS_TIME = 0
local FLAG_UTF8 = 2048
local ATTR_DIRECTORY = 16
local MADE_BY_UNIX = 768
local TYPE_FILE = tonumber('100000', 8)
local TYPE_DIRECTORY = tonumber('40000', 8)
local MODE_FILE = tonumber('644', 8)
local MODE_DIRECTORY = tonumber('755', 8)
local MAX_ENTRIES = 65535
local MAX_SIZE = 2^32 - 1

local function le16(value)
    return string.char(value % 256, floor(value / 256) % 256)
end

local function le32(value)
    return string.char(
        value % 256,
        floor(value / 256) % 256,
        floor(value / 65536) % 256,
        floor(value / 16777216) % 256
    )
end

local function to_mode(mode, default)
    if type(mode) == 'string' then
        return tonumber(mode, 8)
    end
    return mode or default
end

local function compress(body, level)
    if level == 0 or #body == 0 then
        return 0, body
    end
    local packed = deflate:CompressDeflate(body, {level = level})
    if #packed >= #body then
        return 0, body
    end
    return 8, packed
end

local function entry(member, level, offset)
    local name = member.name
    if type(name) ~= 'string' or #name == 0 then
        error('zip member name is required')
    end
    if name:sub(1, 1) == '/' or name:find('\\', 1, true) then
        error('invalid zip member name: '..name)
    end

    local is_dir = name:sub(-1) == '/'
    local body = is_dir and '' or (member.body or '')
    local method, data = compress(body, member.level or level)
    if #body > MAX_SIZE or offset > MAX_SIZE then
        error('zip64 not supported: '..name)
    end

    local flags = name:find('[\128-\255]') and FLAG_UTF8 or 0
    local version = method == 8 and 20 or 10
    local crc = hash.crc32(body)
    local mode = to_mode(member.mode, is_dir and MODE_DIRECTORY or MODE_FILE) % 4096
    local attributes = (mode + (is_dir and TYPE_DIRECTORY or TYPE_FILE)) * 2^16

    local fields = le16(version)
        ..le16(flags)
        ..le16(method)
        ..le16(DOS_TIME)
        ..le16(DOS_DATE)
        ..le32(crc)
        ..le32(#data)
        ..le32(#body)
        ..le16(#name)
        ..le16(0)

    local header = LOCAL_SIGNATURE..fields..name
    local central = CENTRAL_SIGNATURE
        ..le16(MADE_BY_UNIX + 20)
        ..fields
        ..le16(0)
        ..le16(0)
        ..le16(0)
        ..le32(attributes + (is_dir and ATTR_DIRECTORY or 0))
        ..le32(offset)
        ..name

    return header, data, central
end

local function encode(members, options)
    local level = options and options.level or 6
    if #members > MAX_ENTRIES then
        error('zip64 not supported: too many members')
    end

    local out = {}
    local directory = {}
    local offset = 0

    for index = 1, #members do
        local header, data, central = entry(members[index], level, offset)
        out[#out + 1] = header
        out[#out + 1] = data
        directory[#directory + 1] = central
        offset = offset + #header + #data
    end

    local central = table.concat(directory)
    out[#out + 1] = central
    out[#out + 1] = END_SIGNATURE
        ..le16(0)
        ..le16(0)
        ..le16(#members)
        ..le16(#members)
        ..le32(#central)
        ..le32(offset)
        ..le16(0)

    return table.concat(out)
end

return {
    encode = encode
}
