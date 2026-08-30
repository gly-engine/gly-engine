local function percent_encode(str)
    return (str:gsub('[^A-Za-z0-9%-_%.~]', function(c)
        return string.format('%%%02X', string.byte(c))
    end))
end

local function search_param(param_list, param_dict)
    local index, params = 1, ''
    while param_list and param_dict and index <= #param_list do
        local param = param_list[index]
        local value = param_dict[param]
        if #params == 0 then
            params = params..'?'
        else
            params = params..'&'
        end
        params = params..percent_encode(param)..'='..percent_encode(value or '')
        index = index + 1
    end
    return params
end

local P = {
    search_param = search_param
}

return P
