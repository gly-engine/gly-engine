local function normalize(tbl, prefix, out)
    out = out or {}
    prefix = prefix or ""

    for key_original, value in pairs(tbl) do
        local key = tostring(key_original):upper():gsub("[^A-Z0-9_]", "_")
        local path = prefix..(prefix ~= "" and "_" or "")..tostring(key):upper()
        if type(value) == "table" then
            normalize(value, path, out)
        elseif type(value) ~= "function" and type(value) ~= "userdata" and type(value) ~= "thread" then
            out[path] = tostring(value)
        end
    end

    return out
end

local function encode(tbl, force_upper)
    local keys, lines = {}, {}
    for key, value in pairs(tbl) do
        local t = type(value)
        if t ~= "table" and t ~= "userdata" and t ~= "function" and t ~= "thread" then
            table.insert(keys, key)
        end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local key_name = force_upper and key:upper() or key
        table.insert(lines, string.format("%s=%s", key_name, tostring(tbl[key])))
    end
    return table.concat(lines, "\n")
end

local function decode(str)
    local result = {}
    for line in str:gmatch("[^\r\n]+") do
        local clean = line:match("^%s*(.-)%s*$")
        if clean ~= "" and not clean:match("^#") then
            local key, value = clean:match("^([^=]+)=(.*)$")
            if key then
                key = key:match("^%s*(.-)%s*$")
                value = value:match("^%s*(.-)%s*$")
                value = value:match('^"(.*)"$') or value:match("^'(.*)'$") or value
                result[key] = value
            end
        end
    end
    return result
end

local P = {
    normalize = normalize,
    decode = decode,
    encode = encode
}

return P