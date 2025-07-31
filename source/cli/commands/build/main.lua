local buildsystem = require('source/cli/tools/buildsystem')
local atobify = require('source/cli/tools/atobify')
local cli_meta = require('source/cli/tools/meta')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')

local function build(args)
    args.outdir = str_fs.path(args.outdir).get_fullfilepath()

    if args.engine then
        args.core = args.engine:gsub('@', '')
        args.run = false
    end

    cli_fs.clear(args.outdir)
    cli_fs.mkdir(args.outdir..'_bundler/')

    local var = cli_meta.vars(args)

    local build_game = buildsystem.from({core='game', bundler=true, outdir=args.outdir})
        :add_core('game', {src=args.src, as='game.lua', prefix='game_', assets=true, cwd=args.cwd})

    local build_core = buildsystem.from(args)
        :add_core('none')
        --
        :add_core('lite', {src='source/engine/core/vacuum/lite/main.lua'})
        --
        :add_core('micro', {src='source/engine/core/vacuum/micro/main.lua'})
        --
        :add_core('nano', {src='source/engine/core/vacuum/nano/main.lua'})
        --
        :add_core('native', {src='source/engine/core/vacuum/native/main.lua'})
        --
        :add_core('love', {src='source/engine/core/bind/love/main.lua'})
        :add_step('love '..args.outdir, {when=args.run})

    if not args.engine then
        local ok, message = build_game:run()
        if not ok then return false, message end
    end

    local ok, message =  build_core:run()
    
    cli_fs.rmdir(args.outdir..'_bundler/')
    
    return ok, message
end

return {
    build = build,
    build_engine = function(args) return build(args, true) end
}