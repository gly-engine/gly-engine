local test = require('tests/framework/microtest')
local zeebo_builder = require('source/cli/build/builder')
local mock_io = require('tests/mock/io')

io.open = mock_io.open({
    ['build/src/lib.lua'] = 'local foo = require(\'z\')\n\n',
    ['build/src/game.lua'] = 'local bar = require(\'src.lib\')\n\n'
})

function test_cwd()
    local args = {}
    local options = {prefix = 'game_', cwd='build'}
    zeebo_builder.build('src', 'game.lua', 'dist', 'main.lua', options, args)
    local dist_file = io.open('dist/main.lua', 'r')
    local dist_text = dist_file and dist_file:read('*a')
    assert(dist_text:find('game_src_lib'))
end

test.unit(_G)
