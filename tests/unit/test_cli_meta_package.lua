local test = require('tests/framework/microtest')
local cli_meta = require('source/cli/tools/meta')

local function control(game)
    return cli_meta.metadata(game).dump.meta.ipk()
end

function test_metadata_id_from_package_json_name()
    local game = '{"name": "tv.zaper.rcweb", "version": "1.2.3"}'
    local data = cli_meta.metadata(game)

    assert(data.meta.id == 'tv.zaper.rcweb', 'name should feed the id')
    assert(data.meta.title == 'tv.zaper.rcweb', 'name is still the title fallback')
end

function test_metadata_id_prefers_explicit_id()
    local game = '{"id": "tv.zaper.rcweb", "name": "Remote Control", "version": "1.2.3"}'
    local data = cli_meta.metadata(game)

    assert(data.meta.id == 'tv.zaper.rcweb', 'explicit id should win over name')
    assert(data.meta.title == 'Remote Control', 'title should not be the id')
end

function test_metadata_id_is_empty_without_source()
    local game = 'local P = {title = "Pong", version = "1.0.0"}\nreturn P'
    local data = cli_meta.metadata(game)

    assert(data.meta.id == '', 'missing id should be empty')
end

function test_dump_ipk_keeps_reverse_dns()
    local out = control('{"name": "tv.zaper.rcweb", "version": "1.2.3"}')

    assert(out:find('Package: tv.zaper.rcweb\n', 1, true), 'dots are valid and should survive')
    assert(out:find('Version: 1.2.3\n', 1, true))
end

function test_dump_ipk_slugify_human_title()
    local out = control('{"title": "My Cool Game!", "version": "1.0.0"}')

    assert(out:find('Package: my-cool-game\n', 1, true), 'human titles should still be slugified')
end

function test_dump_ipk_slugify_collapses_separators()
    local out = control('{"title": " -- Pong :: The Game -- ", "version": "1.0.0"}')

    assert(out:find('Package: pong-the-game\n', 1, true), 'separators should collapse and trim')
end

function test_dump_ipk_keeps_valid_debian_chars()
    local out = control('{"title": "Pong++ v2.0", "version": "2.0.0"}')

    assert(out:find('Package: pong++-v2.0\n', 1, true), 'plus and dot are valid in package names')
end

function test_dump_ipk_id_wins_over_title()
    local out = control('{"id": "tv.zaper.rcweb", "name": "Remote Control", "version": "1.2.3"}')

    assert(out:find('Package: tv.zaper.rcweb\n', 1, true), 'id should be the package name')
end

test.unit(_G)
