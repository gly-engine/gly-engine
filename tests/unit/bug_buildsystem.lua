local test = require('tests/framework/microtest')
local zeebo_bundler = require('source/cli/build/bundler')
local zeebo_buildsystem = require('source/cli/tools/buildsystem')
local mock_io = require('tests/mock/io')

io.open = mock_io.open({
    ['src/lib/object/application.lua'] = 'local math = require(\'math\')',
    ['src/main103.lua'] = 'local os = require(\'os\')\n'
        ..'local application_default = require(\'src/lib/object/application\')\n'
        ..'local application = require(\'src/lib/object/application\')\n',
    ['src/main104.lua'] = 'local application = require(\'src/lib/object/application\')\n'
        ..'-- local foo = require(\'foo\')\n'
        ..'local baz = 5 -- std.node.load(\'bar.lua\') \n'
})

function test_bug_103_bundler_repeats_packages_with_different_variables()
    zeebo_bundler.build('src/main103.lua', 'dist/main103.lua')
    local dist_file = io.open('dist/main103.lua', 'r')
    local dist_text = dist_file and dist_file:read('*a')
    local count = select(2, dist_text:gsub('= nil', ''))
    assert(count == 1)
    assert(dist_text:find('application_default = src_lib_object_application'))
    assert(dist_text:find('application = src_lib_object_application'))
end

function test_bug_104_builder_includes_commented_libs()
    zeebo_buildsystem.from({core='bug', bundler=true, dist='./dist/'})
        :add_core('bug', {src='src/main104.lua'})
        :run()

    local dist_text = (io.open('dist/main104.lua', 'r')):read('*a')

    assert(dist_text:find('math'))
    assert(not dist_text:find('foo'))
    assert(not dist_text:find('bar'))
end

test.unit(_G)
