--! @brief get value of a compound flag
--! @param[in] args list of arguments
--! @param[in] key single char flag
--! @return string
--! @retval value when found
--! @retval default when not found
--! @retval NULL when found and not set default
local function shared_args_get(args, key, default)
    if not args then return default end
    local index = 1
    local value = default    
    while index <= #args do
        local param = args[index]
        local nextparam = args[index + 1]
        if param:sub(1, 2) == '-'..'-' and param:sub(3, #param) == key and nextparam and nextparam:sub(1, 2) ~= '-'..'-' then
            value = nextparam
        end 
        index = index + 1
    end
    return value
end

--! @brief verify if exist a flag
--! @param[in] args list of arguments
--! @param[in] key single char flag
--! @return boolean
--! @retval true when found
--! @retval false when not found
local function shared_args_has(args, key)
    if not args then return false end
    local index = 1
    while index <= #args do
        local param = args[index]
        if param:sub(1, 2) == '-'..'-' and param:sub(3, #param) == key then
            return true
        end 
        index = index + 1
    end
    return false
end

--! @brief get a ordered param
--! @see take care when using @ref shared_args_get
--! @param[in] args list of arguments
--! @param[in] ignore_keys a list of compound flags to ignore
--! @param[in] position order of parameter started by 1
--! @return string
--! @retval value when found
--! @retval default when not found
--! @retval NULL when found and not set default
local function shared_args_param(args, ignore_keys, position, default)
    if not args then return default end
    local index = 1
    local count = 1
    local ignore_keys2 = {}
    local value = default   
    
    while index <= #ignore_keys do
        ignore_keys2[ignore_keys[index]] = true
        index = index + 1
    end
    
    index = 1
    while index <= #args do
        local arg = args[index]
        local param = args[index - 1]
        if arg:sub(1, 2) ~= '-'..'-' then
            if index <= 1 or (param and not (param:sub(1, 2) == '-'..'-' and ignore_keys2[param:sub(3, #param)])) then
                if position == count then
                    value = arg
                end
                count = count + 1
            end
        end 
        index = index + 1
    end

    return value
end

local P = {
    has = shared_args_has,
    get = shared_args_get,
    param = shared_args_param
}

return P
