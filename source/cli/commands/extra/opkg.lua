local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local ipk_encode = require('source/shared/archive/ipk/encode')

local EXEC_MODE = tonumber('755', 8)

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

local function exists(path)
    return os.rename(path, path) ~= nil
end

--! @short what a package folder must look like, for the error messages
local function layout(dir)
    return '\na package folder needs:\n'
        ..'  '..dir..'/control   Package:, Version: and the other fields\n'
        ..'  '..dir..'/data/     the files, as they go from the device root'
end

--! @short pack indir/control + indir/data/ (the install root) into an .ipk in outdir
local function opkg_build(args)
    local indir = str_fs.path(args.indir).get_fullfilepath()
    local outdir = str_fs.path(args.outdir).get_fullfilepath()
    local dir = #indir > 0 and indir:gsub('[/\\]$', '') or '.'
    local files = {}

    if #indir > 0 and not exists(indir) then
        return false, 'package folder not found: '..dir
    end
    local control = read_file(indir..'control')
    if not control then
        return false, 'missing '..dir..'/control'..layout(dir)
    end
    if not exists(indir..'data') then
        return false, 'missing '..dir..'/data/'..layout(dir)
    end

    local executables = cli_fs.executables(indir..'data')
    for _, name in ipairs(cli_fs.files(indir)) do
        local rel = name:match('^data/(.+)$')
        if rel then
            local body = read_file(indir..name)
            if not body then
                return false, 'cannot read '..dir..'/'..name
            end
            files[#files + 1] = {name = rel, body = body, mode = executables[rel] and EXEC_MODE or nil}
        elseif name ~= 'control' then
            return false, 'unexpected '..dir..'/'..name:match('^[^/]*')..layout(dir)
        end
    end

    local name, ipk = ipk_encode.encode(control, files)
    if not name then
        return false, dir..'/'..ipk
    end

    if #outdir > 0 then
        cli_fs.mkdir(outdir)
    end
    if not write_file(outdir..name, ipk) then
        return false, 'cannot write '..outdir..name
    end
    return true, outdir..name
end

local P = {
    ['opkg-build'] = opkg_build
}

return P
