local zeebo_fs = require('src/lib/cli/fs')
local zeebo_module = require('src/lib/common/module')
local json = require('third_party/json/rxi')
local version = require('src/version')
local lustache = require('third_party/lustache/olivinelabs')

local function replace(args)
    local file_in = io.open(args.file,'r')

    if not file_in then
        return false, 'file not found: '..args.file
    end
    
    local content = (file_in:read('*a') or ''):gsub(args.format, args.replace)
    file_in:close()

    local file_out = io.open(args.dist, 'w')

    file_out:write(content)
    file_out:close()

    return true
end

local function download(args)
    return false, 'not implemented!'
end

local function copy(args)
    return zeebo_fs.move(args.file, args.dist)
end

local function mustache(args)
    local file_json, ferr_json = io.open(args.game_or_json, 'r')
    local file_input, ferr_input = io.open(args.file, 'r')
    local file_output, ferr_output = io.open(args.dist, 'w')

    if not file_json then
        return false, ferr_json or 'missing game or json'
    end

    if not file_input then
        return false, ferr_input or 'missing input'
    end

    if not file_output then
        return false, ferr_output or 'missing output'
    end

    local content_json = file_json:read('*a')
    local content_input = file_input:read('*a')
    local metatable_json = {}

    if not args.game then
        metatable_json = json.decode(content_json)
    else
        local game = zeebo_module.loadgame(content_json)
        metatable_json = {
            meta = game.meta,
            config = game.config,
            engine = {
                version = version
            },
            asset = {
                list = game.assets,
                from = function(self)
                    return self:match('^(.+):.+$')
                end,
                to = function(self)
                    return self:match('^.+:(.+)$')
                end
            },
            fn = {
                msdos_case = function(text, render)
                    return render(text):upper():gsub('[^%a%d]', '')
                end
            }
        }
    end

    local ok, content = pcall(lustache.render, lustache, content_input, metatable_json)

    if not ok then
        return false, content
    end

    file_output:write(content)
    file_json:close()
    file_input:close()
    file_output:close()
    
    return true
end

local function vim_xxd_i(args)
    local file_in = io.open(args.file, 'rb')
    local file_out = args.dist and io.open(args.dist, 'w')

    if not file_in then
        return false, 'file not found: '..args.file
    end

    if not file_out then
        if args.dist then
            return false, 'failed to write:'..args.dist
        else
            file_out = io.stdout
        end
    end

    local length, column = 0, 0
    local const =  args.const and 'const ' or '' 
    local var_name = args.name or args.file:gsub('[%._/]', '_'):gsub("__+", "_"):gsub('^_', '')

    file_out:write(const..'unsigned char '..var_name..'[] = {')
    repeat
        local index = 1
        local chunk = file_in:read(4096)
        local line = column <= 1 and '  ' or ''
        while chunk and index <= #chunk do
            if length > 0 then
                line = line..', '
            end
            if column == 0 or column > 12 then
                line = line..'\n  '
                column = 1
            end
            line = line..string.format('0x%02x', string.byte(chunk, index))
            length = length + 1
            column = column + 1
            index = index + 1
        end
        if line ~= '  ' then
            file_out:write(line)
        end
    until not chunk
    file_out:write('\n};\n'..const..'unsigned int '..var_name..'_len = '..tostring(length)..';\n')

    return true
end

local function luaconf(args)
    local file_in, file_err = io.open(args.file, 'r')

    if not file_in then
        return false, file_err
    end

    local content = file_in:read('*a')
    file_in:close()

    if args['32bits'] then
        content = content:gsub('#define%sLUA_32BITS%s%d', '#define LUA_32BITS 1')
    end

    local file_out = io.open(args.file, 'w')

    file_out:write(content)
    file_out:close()

    return true
end

local P = {
    ['fs-copy'] = copy,
    ['fs-xxd-i'] = vim_xxd_i,
    ['fs-luaconf'] = luaconf,
    ['fs-replace'] = replace,
    ['fs-download'] = download,
    ['fs-mustache'] = mustache
}

return P
