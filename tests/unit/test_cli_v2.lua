local test = require('tests/framework/microtest')
local cli2 = require('source/shared/string/dsl/cli2')
local json = require('source/third_party/rxi_json')

local commands = json.decode_file('cmds.json')
local ok_dsl, msg_dsl, dsl = cli2.load_cmds(commands)

assert(ok_dsl, msg_dsl)

function test_basic_command_validation()
    local ok, out, state = cli2.parse(dsl, {'build', 'samples/pong/game.lua'})
    assert(ok == true)
    assert(state.command == 'build')
    assert(state.src == 'samples/pong/game.lua')
end

function test_core_resolution_and_fixed_values()
    local ok, out, state = cli2.parse(dsl, {'build', '--core', 'html5:webos', 'samples/pong/game.lua'})
    assert(ok == true)
    assert(state.core == 'html5:webos')
    assert(state.atob == true)
end

function test_boolean_flag_handling_and_error_rules()
    local ok, out, state = cli2.parse(dsl, {'build', '--core', 'ginga', '--enterprise', 'samples/pong/game.lua'})
    assert(ok == true)
    assert(state.enterprise == true)
    
    local ok2, out2, state2 = cli2.parse(dsl, {'build', '--core', 'ginga', 'samples/pong/game.lua'})
    assert(ok2 == false)
    assert(out2:find("please use flag %-%-enterprise") ~= nil)
end

function test_shortcuts_resolution()
    local ok, out, state = cli2.parse(dsl, {'build', '@pong'})
    assert(ok == true)
    assert(state.src == 'samples/pong/game.lua')
end

function test_fixed_flag_override_prevention()
    local ok, out, state = cli2.parse(dsl, {'build', '--core', 'html5:ginga', '--fengari=false', '@pong'})
    assert(ok == false)
    assert(out:find("Unknown option: %-%-fengari=false") ~= nil)
end

function test_engine_shortcut_default()
    local ok1, out1, state1 = cli2.parse(dsl, {'build', '--core', 'tic80', '@pong'})
    assert(ok1 == true)
    assert(state1.engine == 'source/engine/core/vacuum/lite/main.lua')


    local ok2, out2, state2 = cli2.parse(dsl, {'build', '--core', 'html5', '@pong'})
    assert(ok2 == true)
    assert(state2.engine == 'source/engine/core/vacuum/native/main.lua')
end

function test_engine_shortcut_micro()
    local ok1, out1, state1 = cli2.parse(dsl, {'build', '--core', 'tic80', '@pong', '--engine', '@micro'})
    assert(ok1 == true)
    assert(state1.engine == 'source/engine/core/vacuum/micro/main.lua')


    local ok2, out2, state2 = cli2.parse(dsl, {'build', '--core', 'html5', '@pong', '--engine', '@micro'})
    assert(ok2 == true)
    assert(state2.engine == 'source/engine/core/vacuum/micro/main.lua')
end

function test_engine_shortcut_native()
    local ok1, out1, state1 = cli2.parse(dsl, {'build', '--core', 'tic80', '@pong', '--engine', '@native'})
    assert(ok1 == true)
    assert(state1.engine == 'source/engine/core/vacuum/native/main.lua')


    local ok2, out2, state2 = cli2.parse(dsl, {'build', '--core', 'html5', '@pong', '--engine', '@native'})
    assert(ok2 == true)
    assert(state2.engine == 'source/engine/core/vacuum/native/main.lua')
end

test.unit(_G)
