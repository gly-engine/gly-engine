local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local str_cmd = require('source/shared/string/schema/cmd')

local function love_exe(args)
    return false, 'not implemented!'
end

local function love_zip(args)
    local path = str_fs.path(args.indir).get_fullfilepath()
    local dist = str_fs.file(args.outfile).get_sys_path()
    local love = str_fs.file(args.outfile).get_file()
    print(path, dist, love)
    os.execute(str_cmd.mkdir()..dist..'_love')
    os.execute(str_cmd.move()..path..'* '..dist..'_love'..str_cmd.silent())
    local zip_pid = io.popen('cd '..dist..'_love && zip -9 -r '..love..' .')
    local stdout = zip_pid:read('*a')
    local ok = zip_pid:close()
    cli_fs.move(dist..'_love/'..love, dist..love)
    cli_fs.clear(dist..'_love')
    os.remove(dist..'_love')
    return ok, stdout
end

local function love_unzip(args)
    cli_fs.clear(args.outdir)
    local f = assert(io.open(args.src, "rb"))
    local data = f:read("*a")
    f:close()

    local zip_start = data:find("PK\003\004", 1, true)
    if not zip_start then
        return false, 'this file is not a Love2D game! (EXE/ZIP)'
    end
    local love_data = data:sub(zip_start)
    local love_out = args.outdir .. "/game.love"
    local flove = assert(io.open(love_out, "wb"))
    flove:write(love_data)
    flove:close()

    os.execute(string.format('cd "%s" && unzip -o "game.love"', args.outdir))
    os.remove(str_fs.path(args.outdir, 'game.love').get_fullfilepath())

    return true
end

local P = {
    ['love-exe'] = love_exe,
    ['love-zip'] = love_zip,
    ['love-unzip'] = love_unzip
}

return P
