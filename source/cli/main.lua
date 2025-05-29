--! @short gly-cli
--! @par Command List
--! @call commands
local os = require('os')

local zeebo_argparse = require('src/lib/cli/argparse')

local commands_build = require('src/cli/commands/build')
local commands_cli = require('src/cli/commands/cli')
local commands_fs = require('src/cli/commands/fs')
local commands_game = require('src/cli/commands/game')
local commands_info = require('src/cli/commands/info')
local commands_init = require('src/cli/commands/init')
local commands_tools = require('src/cli/commands/tools')

local command = zeebo_argparse.from(arg)
    .add_subcommand('init', commands_init)
    .add_next_value('project', {required=true})
    .add_option_get('template', {alias='@samples/{{template}}/game.lua', default='samples/helloworld/game.lua'})
    --
    .add_subcommand('build', commands_build)
    .add_next_value('game', {alias='@samples/{{game}}/game.lua'})
    .add_option_get('core', {})
    .add_option_get('dist', {default='./dist/'})
    .add_option_get('screen', {hidden=true})
    .add_option_has('gpl3', {hidden=true})
    .add_option_has('enterprise', {hidden=true})
    .add_option_has('gamepadzilla', {hidden=true})
    .add_option_has('fengari', {hidden=true})
    .add_option_has('dev', {hidden=true})
    .add_option_has('videojs', {hidden=true})
    .add_option_has('videofake', {hidden=true})
    .add_option_has('enginecdn', {hidden=true})
    .add_option_has('bundler')
    .add_option_has('run')
    --
    .add_subcommand('run', commands_game)
    .add_next_value('game', {required=true, alias='@samples/{{game}}/game.lua'})
    .add_option_get('screen', {})
    --
    .add_subcommand('meta', commands_game)
    .add_next_value('game', {required=true, alias='@samples/{{game}}/game.lua'})
    .add_option_get('format', {default='{{title}} {{version}}', alias=commands_game.meta_alias})
    --
    .add_subcommand('bundler', commands_tools)
    .add_next_value('file', {required=true})
    .add_option_get('dist', {default='./dist/'})
    --
    .add_subcommand('compiler', commands_tools)
    .add_next_value('file', {required=true})
    .add_option_get('dist', {default='a.out'})
    --
    .add_subcommand('tool-haxe-build', commands_tools)
    .add_next_value('game', {required=true})
    --
    .add_subcommand('tool-love-zip', commands_tools)
    .add_next_value('path', {required=true})
    .add_option_get('dist', {default='./dist/'})
    --
    .add_subcommand('tool-love-exe', commands_tools)
    .add_next_value('file', {required=true})
    .add_option_get('dist', {required=true})
    --
    .add_subcommand('tool-package-mock', commands_tools)
    .add_next_value('mock', {required=true})
    .add_next_value('file', {required=true})
    .add_next_value('module', {required=true})
    --
    .add_subcommand('tool-template-fill', commands_tools)
    .add_next_value('file', {required=true})
    .add_next_value('size', {required=true}) 
    --
    .add_subcommand('tool-template-replace', commands_tools)
    .add_next_value('src', {required=true})
    .add_next_value('game', {required=true}) 
    .add_next_value('output', {required=true})
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
    .add_subcommand('fs-mustache', commands_fs)
    .add_next_value('game_or_json', {required=true})
    .add_next_value('file', {required=true})
    .add_next_value('dist', {required=true})
    .add_option_has('game')
    --
    .add_subcommand('cli-build', commands_cli)
    .add_option_get('dist', {default='./dist/'})
    .add_subcommand('cli-test', commands_cli)
    .add_option_has('coverage')
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
