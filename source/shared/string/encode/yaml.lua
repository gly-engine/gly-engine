local function get_max_width(indent)
    if indent <= 40 then
        return 80
    else
        return nil
    end
end

local function wrap_text(text, indent)
    local max_width = get_max_width(indent)
    local prefix = string.rep("  ", indent)
    if not max_width then
        local lines = {}
        for line in text:gmatch("[^\n]+") do
            table.insert(lines, prefix .. line)
        end
        return table.concat(lines, "\n")
    end
    local words = {}
    for word in text:gmatch("%S+") do table.insert(words, word) end
    local lines = {}
    local line = ""
    for _, word in ipairs(words) do
        if #line + #word + 1 > max_width - indent * 2 then
            table.insert(lines, prefix .. line)
            line = word
        else
            if line == "" then
                line = word
            else
                line = line .. " " .. word
            end
        end
    end
    if line ~= "" then table.insert(lines, prefix .. line) end
    return table.concat(lines, "\n")
end

local function sanitize_key(key)
    if type(key) ~= "string" then
        key = tostring(key)
    end
    key = key:gsub("[^%w_-]", "_")
    return key
end

local function should_quote(s)
    if type(s) ~= "string" then return false end
    if s:match("^[^%a_]") or s:match("^%d+$") then
        return true
    end
    if s == "true" or s == "false" or s == "null" then
        return false
    end
    return false
end

local function format_string(s, indent)
    if type(s) ~= "string" then
        return tostring(s)
    end
    local max_width = get_max_width(indent)
    if s:find("\n") then
        local lines = {}
        for line in s:gmatch("[^\n]+") do
            if max_width then
                line = wrap_text(line, indent + 1)
            else
                line = string.rep("  ", indent + 1) .. line
            end
            table.insert(lines, line)
        end
        return "|-\n" .. table.concat(lines, "\n")
    elseif max_width and #s > max_width - indent * 2 then
        return ">-\n" .. wrap_text(s, indent + 1)
    elseif should_quote(s) then
        return string.format("%q", s)
    else
        return s
    end
end

local function to_yaml(tbl, indent)
    indent = indent or 0
    local yaml = ""
    local prefix = string.rep("  ", indent)
    local nums = {}
    local keys = {}
    for k, v in pairs(tbl) do
        if type(v) ~= "function" then
            if type(k) == "number" then
                table.insert(nums, k)
            else
                table.insert(keys, k)
            end
        end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = tbl[k]
        local safe_key = sanitize_key(k)
        if type(v) == "table" then
            yaml = yaml .. prefix .. safe_key .. ":\n" .. to_yaml(v, indent + 1)
        else
            yaml = yaml .. prefix .. safe_key .. ": " .. format_string(v, indent) .. "\n"
        end
    end
    table.sort(nums)
    for _, k in ipairs(nums) do
        local v = tbl[k]
        if type(v) == "table" then
            yaml = yaml .. prefix .. "-\n" .. to_yaml(v, indent + 1)
        else
            yaml = yaml .. prefix .. "- " .. format_string(v, indent) .. "\n"
        end
    end
    return yaml
end

return {
    encode = to_yaml
}
