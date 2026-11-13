local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local zip_encode = require('source/shared/archive/zip/encode')
local zip_decode = require('source/shared/archive/zip/decode')

local function read_file(path)
    local file = io.open(path, 'rb')
    if not file then
        return nil
    end
    local content = file:read('*a')
    file:close()
    return content
end

local function write_file(path, content)
    local file = io.open(path, 'wb')
    if not file then
        return false
    end
    file:write(content)
    file:close()
    return true
end

local function safe_name(name)
    return name:sub(1, 1) ~= '/'
        and not name:find('\\', 1, true)
        and not name:find(':', 1, true)
        and not ('/'..name..'/'):find('/%.%./')
end

local function love_exe(args)
    return false, 'not implemented!'
end

local function love_zip(args)
    local path = str_fs.path(args.indir).get_fullfilepath()
    local outfile = str_fs.file(args.outfile).get_fullfilepath()
    local love = str_fs.file(args.outfile).get_file()
    local members = {}

    if #path == 0 then
        return false, 'love-zip needs an input directory'
    end

    for _, name in ipairs(cli_fs.files(path)) do
        if name ~= love then
            local body = read_file(path..name)
            if not body then
                return false, 'cannot read: '..path..name
            end
            members[#members + 1] = {name = name, body = body}
        end
    end

    if #members == 0 then
        return false, 'nothing to pack in '..path
    end

    cli_fs.clear(path)
    if not write_file(outfile, zip_encode.encode(members)) then
        return false, 'cannot write: '..outfile
    end
    return true
end

local function love_unzip(args)
    local data = read_file(args.src)
    if not data then
        return false, 'cannot read: '..args.src
    end

    local ok, members = pcall(zip_decode.decode, data)
    if not ok then
        return false, 'this file is not a Love2D game! (EXE/ZIP)'
    end

    local outdir = str_fs.path(args.outdir).get_fullfilepath()
    if #outdir == 0 then
        return false, 'love-unzip needs an output directory'
    end

    for _, member in ipairs(members) do
        if not safe_name(member.name) then
            return false, 'unsafe path in zip: '..member.name
        end
    end

    cli_fs.clear(outdir)

    for _, member in ipairs(members) do
        local name = member.name
        local dir = name:match('^(.*)/[^/]*$')
        if dir then
            cli_fs.mkdir(outdir..dir)
        end
        if name:sub(-1) ~= '/' and not write_file(outdir..name, member.body) then
            return false, 'cannot write: '..outdir..name
        end
    end

    return true
end

local P = {
    ['love-exe'] = love_exe,
    ['love-zip'] = love_zip,
    ['love-unzip'] = love_unzip
}

return P
