local function module_mock(src_in, mock_in, module_name)
    local content = ''
    local src_file, src_err = io.open(src_in, 'r')
    local mock_file, mock_err = io.open(mock_in, 'r')

    if not src_file or not mock_file then
        return false, src_err or mock_err
    end

    local in_module = false
    local pattern1 = module_name..'_%w+ = function'
    local pattern2 = '%-%-'

    repeat
        local line = src_file:read()

        if line then
            if not in_module then
                content = content..line..'\n'
            end

            if not in_module and line:find(pattern1) then
                content = content..mock_file:read('*a')
                in_module = true
            end

            if in_module and line:find(pattern2) then
                content = content..'end\n-'..'-\n'
                in_module = false
            end
        end
    until not line

    src_file:close()
    src_file = io.open(src_in, 'wb')
    src_file:write(content)
    src_file:close()

    return true
end

local P = {
    mock = module_mock
}

return P
