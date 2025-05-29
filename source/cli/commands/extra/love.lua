local zeebo_compiler = require('src/lib/cli/compiler')
local zeebo_bundler = require('src/lib/cli/bundler')
local zeebo_package = require('src/lib/cli/package')
local zeebo_filler = require('src/lib/cli/filler')
local zeebo_fs = require('src/lib/cli/fs')
local util_fs = require('src/lib/util/fs')
local util_cmd = require('src/lib/util/cmd')

local function bundler(args)
    local d = util_fs.path(args.dist)
    local f = util_fs.file(args.file)
    zeebo_fs.clear(d.get_fullfilepath())
    return zeebo_bundler.build(f.get_fullfilepath(), d.get_sys_path()..f.get_file())
end

local function compiler(args)
    local file = util_fs.file(args.file).get_fullfilepath()
    local dist = util_fs.file(args.dist).get_fullfilepath()
    return zeebo_compiler.build(file, dist)
end

local function love_zip(args)
    local dist = util_fs.path(args.dist).get_fullfilepath()
    local path = util_fs.path(args.path).get_fullfilepath()
    os.execute(util_cmd.mkdir()..dist..'_love')
    os.execute(util_cmd.move()..path..'* '..dist..'_love'..util_cmd.silent())
    local zip_pid = io.popen('cd '..dist..'_love && zip -9 -r Game.love .')
    local stdout = zip_pid:read('*a')
    local ok = zip_pid:close()
    zeebo_fs.move(dist..'_love/Game.love', dist..'Game.love')
    zeebo_fs.clear(dist..'_love')
    os.remove(dist..'_love')
    return ok, stdout
end

local function love_exe(args)
    return false, 'not implemented!'
end

local function haxe_build(args)
    local game_name = args.game
    local game_file, file_error = io.open(game_name, 'r')
    local game_content = game_file and game_file:read('*a')

    if file_error then
        return false, file_error
    end

    local pattern_utf8 = '_G%.require%("lua%-utf8"%)'
    local replace_utf8 = 'select(2, pcall(require, "lua-utf8")) or select(2, pcall(require, "utf8")) or string'
    local pattern_object = 'std%.(%w+):(%w+)'
    local replace_object = 'std.%1.%2'

    game_content = game_content:gsub(pattern_utf8, replace_utf8)
    game_content = game_content:gsub(pattern_object, replace_object)

    game_file:close()
    game_file, file_error = io.open(game_name, 'w')

    if file_error then
        return false, file_error
    end

    game_file:write(game_content)
    game_file:close()
    
    return true
end

local function package_mock(args)
    return zeebo_package.mock(args.file, args.mock, args.module)
end

local function template_fill(args)
    return zeebo_filler.put(args.file, tonumber(args.size))
end

local function template_replace(args)
    local src = util_fs.file(args.src).get_fullfilepath()
    local game = util_fs.file(args.game).get_fullfilepath()
    local output = util_fs.file(args.output).get_fullfilepath()
    return zeebo_filler.replace(src, game, output, args.size)
end

local P = {
    bundler = bundler,
    compiler = compiler,
    ['tool-haxe-build'] = haxe_build,
    ['tool-love-zip'] = love_zip,
    ['tool-love-exe'] = love_exe,
    ['tool-package-mock'] = package_mock,
    ['tool-template-fill'] = template_fill,
    ['tool-template-replace'] = template_replace
}

return P
