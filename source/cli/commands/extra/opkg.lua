local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local ipk_encode = require('source/shared/archive/ipk/encode')
local ipk_decode = require('source/shared/archive/ipk/decode')
local protect = require('source/cli/tools/protect')

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

--! @short file or folder exists, os.rename for native lua and io.open for nodejs
--! (whose io is backed by node fs, while wasmoon os sees only its virtual filesystem)
local function exists(path)
    if os.rename(path, path) then
        return true
    end
    local file = io.open(path)
    if file then
        file:close()
        return true
    end
    return false
end

--! @short what a package folder must look like, for the error messages
local function layout(dir)
    return '\na package folder needs:\n'
        ..'  '..dir..'/control   Package:, Version: and the other fields\n'
        ..'  '..dir..'/data/     the files, as they go from the device root'
end

--! @short the executable bit of a tar mode, to put back on an extracted file
local function is_executable(mode)
    return mode and math.floor(mode / tonumber('100', 8)) % 2 == 1
end

--! @short write body at path, making the folders it needs on the way
--! @details every mkdir is a process, so a package of hundreds of files only
--! pays for the folders it has not made yet
local function write_deep(path, body, made)
    local dir = path:match('^(.*)/[^/]*$')
    if dir and not made[dir] then
        made[dir] = true
        cli_fs.mkdir(dir)
    end
    return write_file(path, body)
end

--! @short the protector of `--key`, nil when the flag was not given
--! @return false and the message when the key cannot be used
local function protector_of(args, needs_private)
    if not args.key then
        return nil
    end
    local protector, err = protect.new(read_file(args.key), args.key)
    if not protector then
        return false, err
    end
    if needs_private and not protector.private then
        return false, args.key..' is a public key, signing a package needs the private one'
    end
    return protector
end

--! @short pack indir/control + indir/data/ (the install root) into an .ipk in outdir
--! @details with `--key key.pem` (nodejs only) the package is signed and its data encrypted
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

    local protector, err = protector_of(args, true)
    if protector == false then
        return false, err
    end
    local options = {protect = protector}

    local name, ipk = ipk_encode.encode(control, files, options)
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

--! @short unpack an .ipk into outdir/control and outdir/data/, the layout opkg-build takes
--! @details with `--key key.pem` (nodejs only) a protected package is verified and decrypted,
--! and the public half of the key is enough, because only signing needs the private one
local function opkg_unzip(args)
    local outdir = str_fs.path(args.outdir).get_fullfilepath()
    local src = str_fs.file(args.src).get_fullfilepath()
    local content = read_file(src)

    if not content then
        return false, 'package not found: '..src
    end

    local protector, err = protector_of(args, false)
    if protector == false then
        return false, err
    end

    local control, files = ipk_decode.decode(content, {protect = protector})
    if not control then
        return false, src..': '..files
    end

    if #outdir > 0 then
        cli_fs.mkdir(outdir)
    end
    if not write_file(outdir..'control', control) then
        return false, 'cannot write '..outdir..'control'
    end

    local made = {}
    cli_fs.mkdir(outdir..'data')
    for _, file in ipairs(files) do
        local path = outdir..'data/'..file.name
        if not write_deep(path, file.body, made) then
            return false, 'cannot write '..path
        end
        if is_executable(file.mode) then
            cli_fs.chmod(path, '755')
        end
    end

    return true, outdir
end

local P = {
    ['opkg-build'] = opkg_build,
    ['opkg-unzip'] = opkg_unzip
}

return P
