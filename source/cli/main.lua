--! @short gly-cli
--! @par Command List
--! @call commands
local os = require('os')
local cli = require('source/shared/string/parse/cli')
local commands_halt = require('source/cli/commands/halt')
local commands_info = require('source/cli/commands/extra/info')
local commands_fs = require('source/cli/commands/extra/fs')
local commands_cli = require('source/cli/commands/extra/cli')
local commands_love = require('source/cli/commands/extra/love')
local commands_hazard = require('source/cli/commands/extra/hazard')

local command = cli.argparse(arg)
    .add_subcommand('init', commands_halt)
    .add_next_value('project', {required=true})
    .add_option_get('outdir', {default='.', hidden=true})
    .add_option_get('template', {alias='@samples/{{template}}/game.lua', default='samples/helloworld/game.lua', hidden=true})
    --
    .add_subcommand('build', commands_halt)
    .add_next_value('src', {required=true, alias='@samples/{{src}}/game.lua'})
    .add_option_get('cwd', {hidden=true})
    .add_option_get('core', {default='none'})
    .add_option_get('outdir', {default='./dist/'})
    .add_option_get('screen', {hidden=true})
    .add_option_has('bundler')
    .add_option_has('run')
    --
    .add_subcommand('build-bin', commands_halt)
    .add_next_value('src', {required=true, alias='@samples/{{src}}/game.lua'})
    .add_option_get('cwd', {hidden=true})
    .add_option_get('target', {required=true})
    .add_option_get('engine', {alias='@source/engine/core/vacuum/{{engine}}/main.lua', default='source/engine/core/vacuum/native/main.lua', hidden=true})
    .add_option_get('outdir', {default='./dist/'})
    --
    .add_subcommand('build-html', commands_halt)
    .add_next_value('src', {required=true, alias='@samples/{{src}}/game.lua'})
    .add_option_get('cwd', {hidden=true})
    .add_option_get('target', {default='html5'})
    .add_option_get('engine', {alias='@source/engine/core/vacuum/{{engine}}/main.lua', default='source/engine/core/vacuum/native/main.lua', hidden=true})
    .add_option_get('outdir', {default='./dist/'})
    .add_option_get('screen', {})
    .add_option_has('gpl3', {hidden=true})
    .add_option_has('gamepadzilla', {hidden=true})
    .add_option_has('fengari', {})
    .add_option_has('atob', {})
    .add_option_has('dev', {})
    .add_option_has('videojs', {})
    .add_option_has('videofake', {hidden=true})
    .add_option_has('enginecdn', {})
    .add_option_has('aa', {})
    --
    .add_subcommand('build-ginga', commands_halt)
    .add_next_value('src', {required=true, alias='@samples/{{src}}/game.lua'})
    .add_option_get('cwd', {hidden=true})
    .add_option_get('target', {required=true})
    .add_option_get('outdir', {default='./dist/'})
    .add_option_has('non-relative')
    .add_option_has('enterprise')
    .add_option_has('bundler')
    .add_option_has('dev')
    .add_option_has('run')
    --
    .add_subcommand('build-engine', commands_halt)
    .add_next_value('engine', {required=true})
    .add_option_get('outdir', {default='./dist/'})
    .add_option_has('bundler')
    --
    .add_subcommand('run', commands_halt)
    .add_next_value('src', {required=true, alias='@samples/{{src}}/game.lua'})
    .add_option_get('screen', {})
    --
    .add_subcommand('meta', commands_halt)
    .add_next_value('src', {required=true, alias='@samples/{{src}}/game.lua', multiple=true})
    .add_option_get('format', {default='{{& meta.title }} {{& meta.version }}'})
    .add_option_get('infile', {hidden=true})
    .add_option_get('outfile', {hidden=true})
    --
    .add_subcommand('test', commands_halt)
    .add_option_get('luabin', {default='lua'})
    .add_option_has('coverage')
    .add_option_has('bundler')
    --
    .add_subcommand('bundler', commands_halt)
    .add_next_value('src', {required=true})
    .add_option_get('outfile', {default='./dist/main.lua'})
    --
    .add_subcommand('compile', commands_halt)
    .add_next_value('src', {required=true})
    .add_option_get('outfile', {default='a.out'})
    --
    .add_subcommand('love-exe', commands_love)
    .add_next_value('src', {required=true})
    .add_option_get('outfile', {required=true})
    --
    .add_subcommand('love-zip', commands_love)
    .add_next_value('indir', {required=true})
    .add_option_get('outfile', {default='./dist/Game.love'})
    --
    .add_subcommand('love-unzip', commands_love)
    .add_next_value('src', {required=true})
    .add_option_get('outdir', {default='./dist/'})
    --
    .add_subcommand('fs-copy', commands_fs)
    .add_next_value('file', {required=true})
    .add_next_value('dist', {required=true})
    --
    .add_subcommand('fs-xxd-i', commands_fs)
    .add_next_value('file', {required=true})
    .add_next_value('dist', {})
    .add_option_get('name', {})
    .add_option_has('const')
    --
    .add_subcommand('fs-check-png', commands_fs)
    .add_next_value('file', {required=true})
    -- 
    .add_subcommand('fs-luaconf', commands_fs)
    .add_next_value('file', {required=true})
    .add_option_has('32bits')
    --
    .add_subcommand('fs-replace', commands_fs)
    .add_next_value('file', {required=true})
    .add_next_value('dist', {required=true})
    .add_option_get('format', {required=true})
    .add_option_get('replace', {required=true})
    --
    .add_subcommand('fs-download', commands_fs)
    .add_next_value('url', {required=true})
    .add_next_value('dist', {required=true})
    --
    .add_subcommand('hazard-package-mock', commands_hazard)
    .add_next_value('mock', {required=true})
    .add_next_value('file', {required=true})
    .add_next_value('module', {required=true})
    --
    .add_subcommand('hazard-template-fill', commands_hazard)
    .add_next_value('file', {required=true})
    .add_next_value('size', {required=true}) 
    --
    .add_subcommand('hazard-template-replace', commands_hazard)
    .add_next_value('src', {required=true})
    .add_next_value('game', {required=true}) 
    .add_next_value('output', {required=true})
    --
    .add_subcommand('cli-build', commands_cli)
    .add_option_get('dist', {default='./dist/'})
    --
    .add_subcommand('cli-dump', commands_cli)
    --
    .add_subcommand('version', commands_info)
    .add_help_subcommand('help', commands_info)
    .add_next_value('usage', {})
    .add_option_has('extra')
    .add_error_cmd_usage('correct-usage', commands_info)
    .add_error_cmd_not_found('not-found', commands_info)

local ok, message = command.run()

if message then
    print(message)
end

if not ok and os and os.exit then
    os.exit(1)
end

return commands_info.meta()
