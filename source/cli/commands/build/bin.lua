local buildsystem = require('source/cli/tools/buildsystem')
local cartbridge = require('source/cli/tools/cartridge')
local packager = require('source/cli/hazard/package')
local cli_meta = require('source/cli/tools/meta')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')

local function build(args)
    args.core = args.target
    args.outdir = str_fs.path(args.outdir).get_fullfilepath()

    cli_fs.clear(args.outdir)
    cli_fs.mkdir(args.outdir..'_bundler/')

    local lazy_meta = cli_meta.lazy_metada(args.outdir..'game.lua')

    local build_game = buildsystem.from({core='game', bundler=true, outdir=args.outdir})
        :add_core('game', {src=args.src, as='game.lua', prefix='game_', assets=true, cwd=args.cwd})

    local build_engine = buildsystem.from({core='engine', bundler=true, outdir=args.outdir})
        :add_core('engine', {src=args.engine, as='engine.lua', assets=true})

    local build_core = buildsystem.from(args)
        :add_core('pico8', {src='source/engine/core/wrappers/pico8/main.lua', force_bundler=true})
        :add_func(packager.builder_mock(args.outdir..'engine.lua', 'source/engine/core/wrappers/pico8/z8_math.lua', 'source_engine_api_math_clib'))
        :add_func(packager.builder_mock(args.outdir..'engine.lua', 'source/engine/core/wrappers/pico8/z8_color.lua', 'source_engine_api_system_color'))
        :add_func(cartbridge.builder_pico8(lazy_meta, args.outdir))
        --
        :add_core('tic80', {src='source/engine/core/wrappers/tic80/main.lua', force_bundler=true})
        :add_func(cartbridge.builder_tic80(lazy_meta, args.outdir))
        --
        :add_common_func(cli_fs.lazy_del(args.outdir..'main.lua'))
        :add_common_func(cli_fs.lazy_del(args.outdir..'game.lua'))
        :add_common_func(cli_fs.lazy_del(args.outdir..'engine.lua'))

    local ok, message = build_game:run()

    if not ok then
        return false, message
    end

    ok, message = build_engine:run()

    if not ok then
        return false, message
    end

    ok, message = build_core:run()
    
    cli_fs.rmdir(args.outdir..'_bundler/')

    return ok, message
end

return {
    build = build
}
