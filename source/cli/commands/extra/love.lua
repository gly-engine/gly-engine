local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local str_cmd = require('source/shared/string/schema/cmd')

local function love_exe(args)
    return false, 'not implemented!'
end

local function love_zip(args)
    local dist = str_fs.path(args.dist).get_fullfilepath()
    local path = str_fs.path(args.path).get_fullfilepath()
    os.execute(str_cmd.mkdir()..dist..'_love')
    os.execute(str_cmd.move()..path..'* '..dist..'_love'..str_cmd.silent())
    local zip_pid = io.popen('cd '..dist..'_love && zip -9 -r Game.love .')
    local stdout = zip_pid:read('*a')
    local ok = zip_pid:close()
    cli_fs.move(dist..'_love/Game.love', dist..'Game.love')
    cli_fs.clear(dist..'_love')
    os.remove(dist..'_love')
    return ok, stdout
end

local function love_unzip(args)
    cli_fs.clear(args.outdir)
    local f = assert(io.open(args.game, "rb"))
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

local function package_mock(args)
    return zeebo_package.mock(args.file, args.mock, args.module)
end

local function template_fill(args)
    return zeebo_filler.put(args.file, tonumber(args.size))
end

local function template_replace(args)
    local src = str_fs.file(args.src).get_fullfilepath()
    local game = str_fs.file(args.game).get_fullfilepath()
    local output = str_fs.file(args.output).get_fullfilepath()
    return zeebo_filler.replace(src, game, output, args.size)
end

local P = {
    ['love-exe'] = love_exe,
    ['love-zip'] = love_zip,
    ['love-unzip'] = love_unzip,
    ['tool-package-mock'] = package_mock,
    ['tool-template-fill'] = template_fill,
    ['tool-template-replace'] = template_replace
}

return P
