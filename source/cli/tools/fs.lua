local str_fs = require('source/shared/string/schema/fs')
local str_cmd = require('source/shared/string/schema/cmd')
local function lazy(func)
    return function(a, b, c)
        return function()
            func(a, b, c)
            return true
        end
    end
end

local function ls(src_path)
    local p = str_fs.path(src_path).get_fullfilepath()
    local ls_cmd = io.popen(str_cmd.lsdir()..p)
    local ls_files = {}

    if ls_cmd then
        repeat
            local line = ls_cmd:read()
            ls_files[#ls_files + 1] = line
        until not line
        ls_cmd:close()
    end

    return ls_files
end

local function files(src_path)
    local p = str_fs.path(src_path).get_fullfilepath()
    local ls_cmd = io.popen(str_cmd.lsfiles(#p > 0 and p or '.'))
    local list = {}
    local root = nil

    if ls_cmd then
        for line in ls_cmd:lines() do
            line = line:gsub('\r$', '')
            if not root then
                root = line:gsub('[/\\]$', '')
            elseif #line > #root + 1 and line:sub(1, #root) == root then
                list[#list + 1] = line:sub(#root + 2):gsub('\\', '/')
            end
        end
        ls_cmd:close()
    end

    table.sort(list)
    return list
end

local function del(src)
    local p = str_fs.file(src).get_fullfilepath()
    os.execute(str_cmd.del()..p..str_cmd.silent())
end

local function mkdir(src_path)
    local p = str_fs.path(src_path).get_fullfilepath()
    os.execute(str_cmd.mkdir()..p..str_cmd.silent())
end

local function rmdir(src_path)
    local p = str_fs.path(src_path).get_fullfilepath()
    os.execute(str_cmd.rmdir()..p..str_cmd.silent())
end

local function clear(src_path)
    local p = str_fs.path(src_path).get_fullfilepath()
    os.execute(str_cmd.mkdir()..p..str_cmd.silent())
    os.execute(str_cmd.rmdir()..p..'*'..str_cmd.silent())
    os.execute(str_cmd.del()..p..'*'..str_cmd.silent())
end

local function move(src_in, dist_out)
    local src_file = io.open(src_in, "rb")
    local dist_file = src_file and io.open(dist_out, "wb")

    if src_file and dist_file then
        repeat
            local buffer = src_file:read(1024)
            if buffer then
                dist_file:write(buffer)
            end
        until not buffer
    end

    if src_file then
        src_file:close()
    end
    if dist_file then
        dist_file:close()
    end
    return true
end

local P = {
    ls = ls,
    files = files,
    del = del,
    move = move,
    clear = clear,
    rmdir = rmdir,
    mkdir = mkdir,
    lazy_del = lazy(del)
}

return P
