local cli_fs = require('source/cli/tools/fs')
local png_validator = require('source/shared/image/check_png')
local check_auto = require('source/shared/image/check_auto')
local y4m_decoder = require('source/shared/image/decoder_y4m')
local enconde_canvas = require('source/shared/image/enconde_canvas')

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
    return cli_fs.move(args.file, args.dist)
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

local function checkpng(args)
    return png_validator.check_error(args.file)
end

local function imageshow(args)
    local file_in, file_err = io.open(args.file, 'rb')

    if not file_in then
        return false, file_err
    end

    local content = file_in:read('*a')
    file_in:close()

    local format = check_auto(content)
    if not format then
        return false, 'unknown image format: '..args.file
    end

    local decoder
    if format == 'y4m' then
        decoder = y4m_decoder.new('rgb')
    else
        return false, 'unsupported image format: '..format
    end

    decoder:push(content)
    while not decoder:is_done() do
        decoder:step(1024)
    end

    local w, h = decoder.w, decoder.h
    local rgba = decoder:close()

    if not rgba then
        return false, 'failed to decode image: '..args.file
    end

    local ops = {
        start = function()
            return { last_y = -1 }
        end,
        pixel = function(canvas, x, y, run_w, run_h, c1, c2, c3)
            if canvas.last_y ~= y then
                if canvas.last_y >= 0 then
                    io.write('\27[0m\n')
                end
                canvas.last_y = y
            end
            io.write(string.format('\27[48;2;%d;%d;%dm', c1, c2, c3))
            io.write(string.rep('  ', run_w))
        end,
        finish = function(canvas)
            io.write('\27[0m\n')
            return canvas
        end
    }

    local encoder = enconde_canvas.new(w, h, 3, ops)
    encoder:push(rgba)
    while not encoder:is_done() do
        encoder:step(64)
    end
    encoder:close()

    return true
end

local P = {
    ['fs-copy'] = copy,
    ['fs-xxd-i'] = vim_xxd_i,
    ['fs-luaconf'] = luaconf,
    ['fs-replace'] = replace,
    ['fs-download'] = download,
    ['fs-check-png'] = checkpng,
    ['fs-image-show'] = imageshow
}

return P
