local test = require('tests/framework/microtest')
local cli_meta = require('source/cli/tools/meta')

local function template()
    local file = io.open('source/engine/meta/html5/index.mustache', 'r')
    assert(file ~= nil, 'html5 template should exist')
    local content = file:read('*a')
    file:close()
    return content
end

function test_metadata_from_html()
    local index = [[
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Pong - 1.2.3</title>
    <meta name="title" content="Pong"/>
    <meta name="author" content="RodrigoDornelles"/>
    <meta name="version" content="1.2.3"/>
    <meta name="description" content="a classic game"/>
  </head>
  <body></body>
</html>
]]
    local data = cli_meta.metadata(index)

    assert(data ~= nil, 'metadata should not be nil')
    assert(data.meta.title == 'Pong', 'title should ignore the version suffix')
    assert(data.meta.author == 'RodrigoDornelles')
    assert(data.meta.version == '1.2.3')
    assert(data.meta.description == 'a classic game')
end

function test_metadata_from_html_without_meta_tags()
    local index = '<!DOCTYPE html><html><head><title>Pong</title></head><body></body></html>'
    local data = cli_meta.metadata(index)

    assert(data.meta.title == 'Pong', 'title element should be the fallback')
    assert(data.meta.version == '0.0.0', 'missing version should be normalized')
    assert(data.meta.author == '')
end

function test_metadata_from_html_social_tags_only()
    local index = [[
<!DOCTYPE html>
<html><head>
<meta property="og:title" content="Pong"/>
<meta property="og:description" content="a classic game"/>
</head></html>
]]
    local data = cli_meta.metadata(index)

    assert(data.meta.title == 'Pong')
    assert(data.meta.description == 'a classic game')
end

function test_metadata_html_does_not_hijack_lua()
    local game = 'local P = {title = "Pong", version = "1.0.0"}\nreturn P'
    local data = cli_meta.metadata(game)

    assert(data.meta.title == 'Pong')
    assert(data.self.meta == nil, 'lua game should not be parsed as html')
end

function test_metadata_html_round_trip()
    local game = [[
local P = {
    title = 'Tom & Jerry',
    author = 'RodrigoDornelles',
    version = '1.2.3',
    description = 'a classic game'
}
return P
]]
    local rendered = cli_meta.render(game, template(), {core = 'html5', cdn = true})
    assert(rendered ~= nil, 'rendered index.html should not be nil')

    local data = cli_meta.metadata(rendered)

    assert(data.meta.title == 'Tom & Jerry', 'escaped entities should round trip')
    assert(data.meta.description == 'a classic game')
    assert(data.meta.author == '', 'template does not emit an author meta tag')
    assert(data.meta.version == '0.0.0', 'template does not emit a version meta tag')
end

function test_metadata_html_merge_with_game()
    local game = 'local P = {title = "Pong", version = "1.0.0"}\nreturn P'
    local index = '<!DOCTYPE html><html><head><meta name="author" content="RodrigoDornelles"/></head></html>'
    local data = cli_meta.metadata({game, index})

    assert(data.meta.title == 'Pong')
    assert(data.meta.version == '1.0.0')
    assert(data.meta.author == 'RodrigoDornelles', 'html should fill missing fields')
end

test.unit(_G)
