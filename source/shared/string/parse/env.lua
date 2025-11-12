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
    local res = {}
    local lineno = 0

    for line in str:gmatch("[^\r\n]+") do
        lineno = lineno + 1
        local l = line:match("^%s*(.-)%s*$")
        if l ~= "" and not l:match("^#") then
            local in_single, in_double, pos = false, false, nil
            for i = 1, #l do
                local c = l:sub(i, i)
                if c == "'" and not in_double then
                    in_single = not in_single
                elseif c == '"' and not in_single then
                    in_double = not in_double
                elseif c == "#" and not in_single and not in_double then
                    pos = i
                    i = #l
                end
            end
            if pos then
                l = l:sub(1, pos - 1)
            end
            local k, v = l:match("^%s*([%w_.]+)%s*=%s*(.*)$")
            if not k then
                return {}
            end
            v = v:match('^"(.*)"$') or v:match("^'(.*)'$") or v
            v = v:match("^%s*(.-)%s*$")
            if res[k] then
                return {}
            end
            res[k] = v
        end
    end

    return res
end

local P = {
    normalize = normalize,
    decode = decode,
    encode = encode
}

return P