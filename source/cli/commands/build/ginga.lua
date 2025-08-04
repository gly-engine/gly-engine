
      

local buildsystem = require('source/cli/tools/buildsystem')
local atobify = require('source/cli/tools/atobify')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')

local function build(args)
    args.outdir = str_fs.path(args.outdir).get_fullfilepath()
    args.core = args.target
    args.screen = '1280x720'
    args.fengari = true  

    cli_fs.clear(args.outdir)
    cli_fs.mkdir(args.outdir..'_bundler/')

    local build_game = buildsystem.from({core='game', bundler=true, outdir=args.outdir})
        :add_core('game', {src=args.src, as='game.lua', prefix='game_', assets=true, cwd=args.cwd})

    local build_core = buildsystem.from(args)
        :add_rule('please use flag -'..'-enterprise to use commercial modules', 'enterprise=false')
        :add_rule('the flag -'..'-run is not available with ginga html5', 'core=html5', 'run=true')
        :add_rule('the flag -'..'-run must be used together with -'..'-dev', 'run=true', 'dev=false')
        :add_core('ncl', {src='ee/engine/core/bind/ginga/main.lua'})
        :add_meta('ee/engine/meta/ginga/ncl.mustache', {as='main.ncl'})
        :add_step('ginga dist/main.ncl -s 1280x720', {when=args.run})
        --
        :add_core('html5', {src='source/engine/core/vacuum/native/main.lua', force_bundler=true})
        :add_meta('source/engine/meta/html5/index.mustache', {as='index.html'})
        --
        :add_common_func(atobify.builder('engine_code', args.outdir..'main.lua', args.outdir..'index.js'), {when=args.core=='html5' and not args.enginecdn})
        :add_common_func(atobify.builder('game_code', args.outdir..'game.lua', args.outdir..'index.js'), {when=args.core=='html5'})
        :add_common_func(cli_fs.lazy_del(args.outdir..'main.lua'), {when=args.core=='html5'})
        :add_common_func(cli_fs.lazy_del(args.outdir..'game.lua'), {when=args.core=='html5'})

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
