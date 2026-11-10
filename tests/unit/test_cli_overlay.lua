local test = require('tests/framework/microtest')
local mock_io = require('tests/mock/io')

io.open = mock_io.open({
    ['ov/overlay.json'] = [[{
        "replace": [
            {"file": "source/engine/main.lua", "with": "stub/main.lua"},
            {"file": "meta/index.mustache", "with": "webos.mustache", "when": ["eq", "core", "html5:webos"]},
            {"file": "meta/home.lua", "with": "home.lua", "when": ["neq", "env.HOME", "false"]},
            {"file": "meta/unset.lua", "with": "unset.lua", "when": ["neq", "env.GLY_OVERLAY_UNSET_VAR", "false"]},
            {"file": "game/index.lua", "with": "game.lua"}
        ],
        "delete": [
            "source/debug.lua",
            {"file": "source/release.lua", "when": ["eq", "core", "html5:webos"]}
        ]
    }]],
    ['ov/only_delete.json'] = '{"delete": ["a.lua"]}',
    ['ov/no_with.json'] = '{"replace": [{"file": "a.lua"}]}',
    ['ov/empty.json'] = '{}',
    ['ov/stub/main.lua'] = 'stub',
    ['ov/game.lua'] = 'game overlay',
    ['ov/broken.json'] = '{"replace": 1}',
    ['source/engine/main.lua'] = 'original',
    ['source/debug.lua'] = 'debug',
    ['source/keep.lua'] = 'keep'
})

local overlay = require('source/cli/tools/overlay')

function test_load_when()
    local files = assert(overlay.load('ov/overlay.json', {core='html5'}))
    assert(files['source/engine/main.lua'] == 'ov/stub/main.lua')
    assert(files['source/debug.lua'] == false)
    assert(files['meta/index.mustache'] == nil)
    assert(files['meta/home.lua'] == 'ov/home.lua')
    assert(files['meta/unset.lua'] == nil)
    assert(files['source/release.lua'] == nil)
    local webos = assert(overlay.load('./ov/overlay.json', {core='html5:webos'}))
    assert(webos['meta/index.mustache'] == 'ov/webos.mustache')
    assert(webos['source/release.lua'] == false)
    local only = assert(overlay.load('ov/only_delete.json', {}))
    assert(only['a.lua'] == false)
end

function test_load_cwd()
    local files = assert(overlay.load('ov/overlay.json', {cwd='build/'}))
    assert(files['game/index.lua'] == 'ov/game.lua')
    assert(files['build/game/index.lua'] == 'ov/game.lua')
end

function test_load_errors()
    assert(not overlay.load('ov/missing.json', {}))
    assert(not overlay.load('ov/broken.json', {}))
    assert(not overlay.load('ov/no_with.json', {}))
    assert(not overlay.load('ov/empty.json', {}))
end

function test_install()
    assert(overlay.install('ov/overlay.json', {}))
    assert(io.open('./source/engine/main.lua'):read('*a') == 'stub')
    assert(io.open('source/debug.lua') == nil)
    assert(io.open('source/keep.lua'):read('*a') == 'keep')
    local out = io.open('source/engine/main.lua', 'w')
    out:write('written')
    out:close()
    assert(io.open('ov/stub/main.lua'):read('*a') == 'stub')
end

test.unit(_G)
