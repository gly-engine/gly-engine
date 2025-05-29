local buildsystem = require('source/cli/tools/buildsystem')
local atobify = require('source/cli/tools/atobify')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local var_build = require('source/shared/var/build/build')

local function build(args)
    args.dist = str_fs.path(args.dist).get_fullfilepath()

    if not args.core and not args.game then
        return false, 'usage: '..args[0]..' build [game] -'..'-core [core]'
    end

    if not args.core then
        args.core = 'html5'
    end

    if args.core == 'html5_ginga' then
        args.fengari = true
    end

    cli_fs.clear(args.dist)
    cli_fs.mkdir(args.dist..'_bundler/')

    local atob = var_build.need_atobify(args)

    local build_game = buildsystem.from({core='game', bundler=true, dist=args.dist})
        :add_core('game', {src=args.game, as='game.lua', prefix='game_', assets=true})

    local build_core = buildsystem.from(args)
        :add_rule('the middlware ginga html5 already has a streamming player', 'core=html5_ginga', 'videojs=true')
        :add_rule('please use flag -'..'-enterprise to use commercial modules', 'core=html5_ginga', 'enterprise=false')
        :add_rule('please use flag -'..'-enterprise to use commercial modules', 'core=ginga', 'enterprise=false')
        :add_rule('please use flag -'..'-gpl3 to use free software modules', 'gamepadzilla=true', 'gpl3=false')
        --
        :add_core('none')
        --
        :add_core('lite', {src='source/engine/core/lite/main.lua'})
        --
        :add_core('micro', {src='source/engine/core/micro/main.lua'})
        --
        :add_core('native', {src='source/engine/core/native/main.lua'})
        --
        :add_core('love', {src='source/engine/core/love/main.lua'})
        :add_step('love '..args.dist, {when=args.run})
        --
        :add_core('ginga', {src='ee/engine/core/ginga/main.lua'})
        :add_meta('ee/engine/meta/ginga/ncl.mustache', {as='main.ncl'})
        :add_step('ginga dist/main.ncl '..var_build.screen_ginga(args), {when=args.run})
        --
        :add_core('html5', {src='source/engine/core/native/main.lua', force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_core('html5_lite', {src='source/engine/core/lite/main.lua', force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_core('html5_micro', {src='source/engine/core/micro/main.lua', force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_core('html5_ginga', {src='source/engine/core/native/main.lua', force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_core('html5_tizen', {src='source/engine/core/native/main.lua', force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        :add_meta('src/engine/meta/html5_tizen/config.xml')
        :add_meta('src/engine/meta/html5_tizen/.tproject')
        :add_step('cd '..args.dist..';~/tizen-studio/tools/ide/bin/tizen.sh package -t wgt;true')
        --
        :add_core('html5_webos', {src='source/engine/core/native/main.lua', force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        :add_meta('src/engine/meta/html5_webos/appinfo.json')
        :add_step('webos24 $(pwd)/dist', {when=args.run})
        --
        :add_common_func(atobify.builder('engine_code', args.dist..'main.lua', args.dist..'index.js'), {when=atob and not args.enginecdn})
        :add_common_func(atobify.builder('game_code', args.dist..'game.lua', args.dist..'index.js'), {when=atob})
        :add_common_func(cli_fs.lazy_del(args.dist..'main.lua'), {when=atob or args.enginecdn})
        :add_common_func(cli_fs.lazy_del(args.dist..'game.lua'), {when=atob})

    local ok, message = build_game:run()

    if not ok then
        return false, message
    end

    ok, message =  build_core:run()
    
    cli_fs.rmdir(args.dist..'_bundler/')

    return ok, message
end

return {
    build = build
}