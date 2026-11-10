local test = require('tests/framework/microtest')
local engine_getenv = require('source/engine/api/system/getenv')

local function setup(host)
    local std = {}
    local engine = {envs = {CORE = 'core', CORE_BLANK = ' '}}
    engine.root = {envs = {GAME = 'game', GAME_NUMBER = 42, GAME_EMPTY = ''}}
    engine.current = engine.root
    engine_getenv.install(std, engine, {get_env = function(name) return host[name] end})
    return std
end

function test_returns_string()
    local std = setup({HOST = 'host'})
    assert(std.getenv('GAME') == 'game')
    assert(std.getenv('CORE') == 'core')
    assert(std.getenv('HOST') == 'host')
    assert(std.getenv('GAME_NUMBER') == '42')
end

function test_nil_when_missing_or_blank()
    local std = setup({HOST_EMPTY = '', HOST_SPACES = '  \t ', HOST_NEWLINE = '\n'})
    assert(std.getenv('MISSING') == nil)
    assert(std.getenv('GAME_EMPTY') == nil)
    assert(std.getenv('CORE_BLANK') == nil)
    assert(std.getenv('HOST_EMPTY') == nil)
    assert(std.getenv('HOST_SPACES') == nil)
    assert(std.getenv('HOST_NEWLINE') == nil)
end

function test_invalid_name()
    local std = setup({})
    assert(std.getenv(nil) == nil)
    assert(std.getenv('') == nil)
    assert(std.getenv(1) == nil)
end

function test_keeps_value_with_spaces()
    local std = setup({HOST = ' a b '})
    assert(std.getenv('HOST') == ' a b ')
end

function test_setenv()
    local std = setup({HOST = 'host'})
    std.setenv('HOST', 'override')
    assert(std.getenv('HOST') == 'override')
    std.setenv('HOST', '   ')
    assert(std.getenv('HOST') == nil)
    std.setenv('HOST', nil)
    assert(std.getenv('HOST') == 'host')
    std.setenv('NUM', 7)
    assert(std.getenv('NUM') == '7')
end

test.unit(_G)
