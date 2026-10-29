--! @short gly-cli
--! @par Command List
--! @call commands
local os = require('os')
local cli2 = require('source/shared/string/dsl/cli2')
local json = require('source/third_party/rxi_json')
local commands_halt = require('source/cli/commands/halt')
local commands_info = require('source/cli/commands/extra/info')
local commands_fs = require('source/cli/commands/extra/fs')
local commands_cli = require('source/cli/commands/extra/cli')
local commands_love = require('source/cli/commands/extra/love')
local commands_hazard = require('source/cli/commands/extra/hazard')
local cli_overlay = require('source/cli/tools/overlay')

--! handlers are named `command` or `command-subcommand`
local handlers = {}
for _, group in ipairs({commands_halt, commands_fs, commands_cli, commands_love, commands_hazard}) do
    for name, func in pairs(group) do
        handlers[name] = func
    end
end
handlers['bundler-lua'] = commands_halt.bundler
handlers['engine'] = commands_halt['build-engine']
handlers['version'] = commands_info.version

--! each `--core` class is built by a handler with a target
local cores = {
    ['none'] = {'build', 'none'},
    ['html5'] = {'build-html', 'html5'},
    ['html5:webos'] = {'build-html', 'webos'},
    ['html5:tizen'] = {'build-html', 'tizen'},
    ['html5:ginga'] = {'build-ginga', 'html5'},
    ['ginga:html5'] = {'build-ginga', 'html5'},
    ['ginga'] = {'build-ginga', 'ncl'},
    ['love'] = {'build', 'love'},
    ['love:zip'] = {'build', 'love'},
    ['love:exe'] = {'love-exe'},
    ['tic80'] = {'build-bin', 'tic80'},
    ['pico8'] = {'build-bin', 'pico8'}
}

--! translate cli v2 state into the args expected by old handlers
local function resolve(state)
    if state.command == 'build' then
        local core = cores[state.core]
        state.target = core[2]
        state['non-relative'] = state['disable-relative']
        if core[1] == 'build' then
            state.core = core[2]
        end
        return core[1]
    end
    if state.command == 'engine' then
        state.engine = state.engine:gsub('^@', '')
    end
    if state.subcommand then
        return state.command..'-'..state.subcommand
    end
    return state.command
end

local function run(state)
    local class = state.core
    if type(state.overlay) == 'string' then
        local ok, err = cli_overlay.install(state.overlay, state)
        if not ok then return false, err end
    end
    local name = resolve(state)
    local handler = handlers[name]
    if not handler then
        return false, 'command not implemented: '..name
    end
    local ok, message = handler(state)
    if ok and class == 'love:zip' then
        return handlers['love-zip']({indir=state.outdir, outfile=state.outdir..'Game.love'})
    end
    return ok, message
end

--! loaded as game by `meta source/cli/main.lua`
if not arg then
    return commands_info.meta()
end

--! bootstrapped cli always use its own cmds.json, never one from the user project
local embedded = BOOTSTRAP and BOOTSTRAP['cmds.json']
local ok, message, state = cli2.load_cmds(embedded and json.decode(embedded) or json.decode_file('cmds.json'))

if ok then
    ok, message, state = cli2.parse(state, arg)
    if ok and state.command then
        ok, message = run(state)
    end
end

if message and message ~= true then
    print(message)
end

if not ok and os and os.exit then
    os.exit(1)
end

return commands_info.meta()
