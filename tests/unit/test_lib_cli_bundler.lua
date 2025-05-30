local test = require('teste/framework/microtest')
local zeebo_bundler = require('source/cli/build/bundler')
local mock_io = require('mock/io')

io.open = mock_io.open({
    ['src/lovemath.lua'] = 'l = true',
    ['src/love.lua'] = 'require "lovemath"\nreturn l',
    ['src/foo.lua'] = 'local math = require(\'math\')',
    ['src/bar.lua'] = 'local z = require(\'foo\')',
    ['src/baz.lua'] = 'local z = require(\'bar\')',
    ['src/biz.lua'] = 'local z = require(\'baz\')',
    ['src/lib_common_math.lua'] = 'local function sum(a, b)\n'
        ..' return a + b\n'
        ..'end\n'
        ..'local P = {\n'
        ..' sum = sum\n'
        ..'}\n'
        ..'return P\n',
    ['src/main.lua'] = 'local os = require(\'os\')\n'
        ..'local zeebo_math = require(\'lib_common_math\')\n'
        ..'return zeebo_math.sum(1, 2)\n'
})

function test_sample()
    zeebo_bundler.build('src/main.lua', 'dist/main1.lua')
    local dist_file = io.open('dist/main1.lua', 'r')
    local dist_text = dist_file and dist_file:read('*a')
    local dist_func = loadstring and loadstring(dist_text) or load(dist_text)
    assert(dist_func() == 3)
end

function test_recursion()
    zeebo_bundler.build('src/biz.lua', 'dist/main2.lua')
    local dist_file = io.open('dist/main2.lua', 'r')
    local dist_text = dist_file and dist_file:read('*a')
    assert(dist_text:match('_G.math'))
end

function test_simple_require()
    zeebo_bundler.build('src/love.lua', 'dist/love.lua')
    local dist_file = io.open('dist/love.lua', 'r')
    local dist_text = dist_file and dist_file:read('*a')
    local dist_func = loadstring and loadstring(dist_text) or load(dist_text)
    assert(dist_func() == true)
end

test.unit(_G)
