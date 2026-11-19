local test = require('tests/framework/microtest')
local html = require('source/shared/string/parse/html')

function test_empty_on_plain_text()
    local data = html.decode('hello world')
    assert(next(data) == nil)
end

function test_empty_on_lua_source()
    local data = html.decode('local P = {title = "pong"}\nreturn P')
    assert(next(data) == nil)
end

function test_title()
    local data = html.decode('<html><head><title>Pong</title></head></html>')
    assert(data.title == 'Pong')
    assert(data.meta == nil)
end

function test_title_trim_and_entities()
    local data = html.decode('<title>\n  Tom &amp; Jerry  \n</title>')
    assert(data.title == 'Tom & Jerry')
end

function test_title_empty()
    local data = html.decode('<title></title>')
    assert(data.title == nil)
end

function test_meta_double_quotes()
    local data = html.decode('<meta name="author" content="Rodrigo"/>')
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_single_quotes()
    local data = html.decode("<meta name='author' content='Rodrigo'>")
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_unquoted()
    local data = html.decode('<meta name=author content=Rodrigo>')
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_uppercase_tag()
    local data = html.decode('<META NAME="Author" CONTENT="Rodrigo">')
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_attribute_order()
    local data = html.decode('<meta content="Rodrigo" name="author">')
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_spaced_equals()
    local data = html.decode('<meta name = "author" content = "Rodrigo">')
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_entities()
    local data = html.decode('<meta name="description" content="a &amp; b &lt;c&gt; &#39;d&#39; &#x41;">')
    assert(data.meta.description == 'a & b <c> \'d\' A')
end

function test_meta_unknown_entity_is_kept()
    local data = html.decode('<meta name="description" content="100&euro;">')
    assert(data.meta.description == '100&euro;')
end

function test_meta_without_content_is_ignored()
    local data = html.decode('<meta charset="utf-8"><meta name="viewport">')
    assert(data.meta == nil)
end

function test_meta_inside_comment_is_ignored()
    local data = html.decode('<!-- <meta name="author" content="ghost"> --><meta name="author" content="real">')
    assert(data.meta.author == 'real')
end

function test_meta_inside_script_is_ignored()
    local data = html.decode('<script>var s = \'<meta name="author" content="ghost">\'</script>')
    assert(data.meta == nil)
end

function test_meta_inside_style_is_ignored()
    local data = html.decode('<style>/* <meta name="author" content="ghost"> */</style>')
    assert(data.meta == nil)
end

function test_meta_property_alias()
    local data = html.decode('<meta property="og:title" content="Pong">')
    assert(data.meta['og:title'] == 'Pong')
    assert(data.meta.title == 'Pong')
end

function test_meta_alias_only_for_known_keys()
    local data = html.decode('<meta property="og:type" content="website"><meta property="og:url" content="http://a.b">')
    assert(data.meta['og:type'] == 'website', 'prefixed key should be kept')
    assert(data.meta['og:url'] == 'http://a.b')
    assert(data.meta.type == nil, 'og:type should not become type')
    assert(data.meta.url == nil, 'og:url should not become url')
end

function test_meta_author_alias()
    local data = html.decode('<meta property="og:author" content="Rodrigo">')
    assert(data.meta.author == 'Rodrigo')
end

function test_meta_twitter_alias()
    local data = html.decode('<meta property="twitter:description" content="a game">')
    assert(data.meta.description == 'a game')
end

function test_meta_name_wins_over_property()
    local source = '<meta property="og:title" content="social"><meta name="title" content="real">'
    local data = html.decode(source)
    assert(data.meta.title == 'real')
end

function test_meta_name_wins_over_later_property()
    local source = '<meta name="title" content="real"><meta property="og:title" content="social">'
    local data = html.decode(source)
    assert(data.meta.title == 'real')
end

function test_meta_first_name_wins()
    local source = '<meta name="title" content="first"><meta name="title" content="second">'
    local data = html.decode(source)
    assert(data.meta.title == 'first')
end

function test_meta_itemprop()
    local data = html.decode('<meta itemprop="author" content="Rodrigo">')
    assert(data.meta.author == 'Rodrigo')
end

function test_metadata_tag_is_not_meta()
    local data = html.decode('<metadata name="author" content="ghost">')
    assert(data.meta == nil)
end

function test_full_document()
    local source = [[
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Pong - 1.0.0</title>
    <meta name="theme-color" content="#000000"/>
    <meta name="title" content="Pong"/>
    <meta name="author" content="RodrigoDornelles"/>
    <meta name="version" content="1.0.0"/>
    <meta name="description" content="a classic game"/>
    <meta property="og:title" content="Pong" />
  </head>
  <body><canvas id="gameCanvas"></canvas></body>
</html>
]]
    local data = html.decode(source)
    assert(data.title == 'Pong - 1.0.0')
    assert(data.meta.title == 'Pong')
    assert(data.meta.author == 'RodrigoDornelles')
    assert(data.meta.version == '1.0.0')
    assert(data.meta.description == 'a classic game')
    assert(data.meta['theme-color'] == '#000000')
    assert(data.meta.color == nil)
end

function test_attributes_boolean()
    local attrs = html.attributes(' src="index.js" defer')
    assert(attrs.src == 'index.js')
    assert(attrs.defer == '')
end

function test_attributes_self_closing_slash()
    local attrs = html.attributes(' name="author" content="Rodrigo" /')
    assert(attrs.name == 'author')
    assert(attrs.content == 'Rodrigo')
end

function test_attributes_equals_inside_value()
    local attrs = html.attributes(' name="viewport" content="width=device-width, initial-scale=1.0"')
    assert(attrs.content == 'width=device-width, initial-scale=1.0')
    assert(attrs.width == nil)
end

test.unit(_G)
