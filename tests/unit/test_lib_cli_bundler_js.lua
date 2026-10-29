local test = require('tests/framework/microtest')
local zeebo_bundler_js = require('source/cli/build/bundler_js')
local mock_io = require('tests/mock/io')

io.open = mock_io.open({
    ['src/main.js'] = 'var b = require(\'./a/b\')\nvar p = require(\'../presets.json\')\nmodule.exports = b.x + p.k',
    ['src/a/b.js'] = 'exports.x = 1',
    ['presets.json'] = '{"k": 2}',
    ['src/dir.js'] = 'module.exports = require(\'./lib\')',
    ['src/lib/index.js'] = 'module.exports = 3'
})

local function read(path)
    local file = io.open(path, 'r')
    return file and file:read('*a')
end

function test_cjs_relative_ids()
    assert(zeebo_bundler_js.build('src/main.js', 'dist/cjs.js'))
    local out = read('dist/cjs.js')
    assert(out:find('module.exports = (function() {', 1, true))
    assert(out:find('__modules[\'main.js\']', 1, true))
    assert(out:find('__modules[\'a/b.js\']', 1, true))
    assert(out:find('__modules[\'../presets.json\']', 1, true))
    assert(out:find('return __require(\'main.js\');', 1, true))
end

function test_no_modern_syntax()
    assert(zeebo_bundler_js.build('src/main.js', 'dist/es5.js'))
    local out = read('dist/es5.js')
    assert(not out:find('const ', 1, true))
    assert(not out:find('let ', 1, true))
end

function test_global()
    assert(zeebo_bundler_js.build('src/main.js', 'dist/global.js', {global='Foo'}))
    assert(read('dist/global.js'):find('window.Foo = (function() {', 1, true))
end

function test_esm()
    assert(zeebo_bundler_js.build('src/main.js', 'dist/esm.js', {format='esm'}))
    assert(read('dist/esm.js'):find('export default (function() {', 1, true))
end

function test_directory_index()
    assert(zeebo_bundler_js.build('src/dir.js', 'dist/dir.js'))
    assert(read('dist/dir.js'):find('__require(\'lib/index.js\')', 1, true))
end

function test_errors()
    assert(not zeebo_bundler_js.build('src/main.js', 'dist/x.js', {format='global'}))
    assert(not zeebo_bundler_js.build('src/main.js', 'dist/x.js', {format='amd'}))
    assert(not zeebo_bundler_js.build('src/missing.js', 'dist/x.js'))
end

test.unit(_G)
