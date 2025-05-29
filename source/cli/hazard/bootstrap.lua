local util_cmd = require('src/lib/util/cmd')

local function bootstrap()
    local fmock = io.open('mock/io.lua', 'r')
    local fbootstrap = io.open('mock/bootstrap.lua', 'r')
    local content = fmock:read('*a'):match('%-%-! @bootstrap(.-)%-%-! @endbootstrap')..fbootstrap:read('*a')
    fmock:close()
    fbootstrap:close()
    return content
end

local function explode_string(input)
    local result = {}
    
    for line in string.gmatch(input, "[^\n]+") do
        table.insert(result, line)
    end
    
    return result
end

local function string_to_hex(input)
    local result = ""
    for i = 1, #input do
        local byte = input:byte(i)
        result = result .. string.format("\\%03d", byte)
    end
    return result
end

local function map_files(files, prefix_len)
    local list_paths = {}
    local list_files = {}
    local dict_files = {}
    local index = 1

    while index <= #files do
        local file_real_path = files[index]
        local file_real = io.open(file_real_path, 'rb')
        local file_real_content = file_real and file_real:read('*a')
        local file_name = file_real_path:sub(prefix_len)
        
        if file_real_content then
            list_files[#list_files + 1] = file_name
            dict_files[file_name] = string_to_hex(file_real_content)
        else 
            list_paths[#list_paths + 1] = file_name
        end

        index = index + 1
    end

    return list_paths, list_files, dict_files
end

local function merge_dict_and_lists(list_out, dict_out, list_in, dict_in)
    local index = 1
    while index <= #list_in do
        local key = list_in[index]
        list_out[#list_out + 1] = key
        if dict_out and dict_in then
            dict_out[key] = dict_in[key]
        end
        index = index + 1
    end
end

local function build(input_name, output_name, input_paths)
    if BOOTSTRAP then
        BOOTSTRAP_DISABLE = true
    end

    local input_file = io.open(input_name, 'r')
    local output_file = io.open(output_name, 'w')

    local index = 1
    local all_list_paths = {}
    local all_list_files = {}
    local all_dict_files = {}
    while index <= #input_paths do
        local path_src = input_paths[index]
        local prefix_path = path_src:match("^(.-)/[^/]+$")
        local prefix_len = 0
        
        if not prefix_path then
            return false, 'src path must be a explicit relative path or absolute'
        elseif path_src:sub(1, 2) == './' then
            prefix_len = 3
        else 
            prefix_len = #prefix_path + 2
        end

        do 
            local f = io.open(path_src, 'rb')
            if not f then 
                return false, 'directory not found'
            end
            local can_read = f:read(1)
            if can_read then
                return false, 'path src must be a directory'
            end
            f:close()
        end

        local cmd_pid = io.popen('find '..path_src)
        local cmd_raw = cmd_pid:read('*a')
        cmd_pid:close()
        local list_raw = explode_string(cmd_raw)
        local list_paths, list_files, dict_files = map_files(list_raw, prefix_len)
        merge_dict_and_lists(all_list_files, all_dict_files, list_files, dict_files)
        merge_dict_and_lists(all_list_paths, nil, list_paths, nil)
        index = index + 1
    end

    output_file:write('local BOOTSTRAP = {}\nlocal BOOTSTRAP_DISABLE = false\n')

    do
        index = 1
        local content = 'local BOOTSTRAP_DIRS = {'
        while index <= #all_list_paths do
            local file_name = all_list_paths[index]
            content = content..'\''..file_name..'\''
            index = index + 1
            if index <= #all_list_paths then
                content = content..', '
            else
                content = content..'}\n'
            end
        end
        output_file:write(content)
    end

    do
        index = 1
        local content = 'local BOOTSTRAP_LIST = {'
        while index <= #all_list_files do
            local file_name = all_list_files[index]
            content = content..'\''..file_name..'\''
            index = index + 1
            if index <= #all_list_files then
                content = content..', '
            else
                content = content..'}\n'
            end
        end
        output_file:write(content)
    end

    do
        index = 1
        while index <= #all_list_files do
            local file_name = all_list_files[index]
            local file_content = all_dict_files[file_name]
            output_file:write('BOOTSTRAP[\''..file_name..'\'] = \''..file_content..'\'\n')
            index = index + 1
        end
    end

    output_file:write(bootstrap())
    output_file:write(input_file:read('*a'))
    output_file:close()
    input_file:close()

    return true
end

local function dump()
    if not BOOTSTRAP then
        return false, 'cli is not bootstraped'
    end

    do
        local index = 1
        while index <= #BOOTSTRAP_DIRS do
            os.execute(util_cmd.mkdir()..BOOTSTRAP_DIRS[index])
            index = index + 1
        end
    end

    do
        local index = 1
        while index <= #BOOTSTRAP_LIST do
            local file = BOOTSTRAP_LIST[index]
            local output_file = io.open(file, 'wb')
            output_file:write(BOOTSTRAP[file])
            output_file:close()
            index = index + 1
        end
    end

    return true
end

local P = {
    build = build,
    dump = dump
}

return P
