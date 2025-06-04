local buildsystem = require('source/cli/tools/buildsystem')
local atobify = require('source/cli/tools/atobify')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local var_build = require('source/shared/var/build/build')

local function build(args)
    args.outdir = str_fs.path(args.outdir).get_fullfilepath()

    if args.core == 'ginga' then
        args.fengari = true
    end

    cli_fs.clear(args.outdir)
    cli_fs.mkdir(args.outdir..'_bundler/')

    local atob = var_build.need_atobify(args)

    local build_game = buildsystem.from({core='game', bundler=true, outdir=args.outdir})
        :add_core('game', {src=args.src, as='game.lua', prefix='game_', assets=true})

    local build_core = buildsystem.from(args)
        :add_rule('the middlware ginga html5 already has a streamming player', 'core=ginga', 'videojs=true')
        :add_rule('please use flag -'..'-enterprise to use commercial modules', 'core=ginga', 'enterprise=false')
        :add_rule('please use flag -'..'-gpl3 to use free software modules', 'gamepadzilla=true', 'gpl3=false')
        --
        :add_core('html5', {src=args.engine, force_bundler=true})
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_core('ginga', {src=args.engine, force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_core('tizen', {src=args.engine, force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        :add_meta('src/engine/meta/html5_tizen/config.xml')
        :add_meta('src/engine/meta/html5_tizen/.tproject')
        :add_step('cd '..args.outdir..';~/tizen-studio/tools/ide/bin/tizen.sh package -t wgt;true')
        --
        :add_core('webos', {src=args.engine, force_bundler=true})
        :add_file('assets/icon80x80.png')
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        :add_meta('src/engine/meta/html5_webos/appinfo.json')
        :add_step('webos24 $(pwd)/dist', {when=args.run})
        --
        :add_common_func(atobify.builder('engine_code', args.outdir..'main.lua', args.outdir..'index.js'), {when=atob and not args.enginecdn})
        :add_common_func(atobify.builder('game_code', args.outdir..'game.lua', args.outdir..'index.js'), {when=atob})
        :add_common_func(cli_fs.lazy_del(args.outdir..'main.lua'), {when=atob or args.enginecdn})
        :add_common_func(cli_fs.lazy_del(args.outdir..'game.lua'), {when=atob})

    local ok, message = build_game:run()

    if not ok then
        return false, message
    end

    ok, message =  build_core:run()
    
    cli_fs.rmdir(args.outdir..'_bundler/')

    return ok, message
end

return {
    build = build
}