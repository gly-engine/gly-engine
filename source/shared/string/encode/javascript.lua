local is_list = require('source/shared/table/is_list')

local function escape_string(str)
    str = str:gsub('\\', '\\\\')
    str = str:gsub('"', '\\"')
    str = str:gsub('\n', '\\n')
    str = str:gsub('\r', '\\r')
    str = str:gsub('\t', '\\t')
    return str
end

local function table_to_js(tbl)
    if is_list.full(tbl) then
        local parts = {}
        for i, v in ipairs(tbl) do
            local value
            if type(v) == "table" then
                value = table_to_js(v)
            elseif type(v) == "string" then
                value = '"' .. escape_string(v) .. '"'
            elseif type(v) == "boolean" or type(v) == "number" then
                value = tostring(v)
            else
                value = "null"
            end
            table.insert(parts, value)
        end
        return "[" .. table.concat(parts, ",") .. "]"
    else
        local parts = {}
        for k, v in pairs(tbl) do
            local key
            if type(k) == "string" and k:match("^%a[%w_]*$") then
                key = k
            else
                key = '["' .. tostring(k) .. '"]'
            end
            local value
            if type(v) == "table" then
                value = table_to_js(v)
            elseif type(v) == "string" then
                value = '"' .. escape_string(v) .. '"'
            elseif type(v) == "boolean" or type(v) == "number" then
                value = tostring(v)
            else
                value = "null"
            end
            table.insert(parts, key .. ":" .. value)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
end

local function dump_named(prefix)
    return function(tbl)
        local lines = {}
        for k, v in pairs(tbl) do
            if type(k) == "string" and k:match("^%a[%w_]*$") then
                local value
                if type(v) == "table" then
                    value = table_to_js(v)
                elseif type(v) == "string" then
                    value = '"' .. escape_string(v) .. '"'
                elseif type(v) == "boolean" or type(v) == "number" then
                    value = tostring(v)
                else
                    value = "null"
                end
                table.insert(lines, prefix .. " " .. k .. "=" .. value .. ";")
            end
        end
        return table.concat(lines, "\n")
    end
end

local function dump_default(prefix)
    return function(tbl)
        return prefix .. table_to_js(tbl) .. ";"
    end
end

return {
    var = dump_named('var'),
    const = dump_named('const'),
    esm = dump_named('export const'),
    esm_default = dump_default('export default '),
    cjs_default = dump_default('module.exports=')
}
