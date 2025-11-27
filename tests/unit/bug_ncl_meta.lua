local test = require('tests/framework/microtest')
local cli_meta = require('source/cli/tools/meta')

function test_bug_255_metadata_includes_custom_screens()
    local game_code = [[
        local P = {
            title = 'Test Game',
            version = '1.0.0',
            screens = {
                {left=100, top=50, width=640, height=360},
                {left=200, top=100, width=800, height=600}
            }
        }
        return P
    ]]
    
    local data = cli_meta.metadata(game_code)
    
    assert(data ~= nil, 'metadata should not be nil')
    assert(data.self ~= nil, 'data.self should exist')
    assert(data.self.screens ~= nil, 'data.self.screens should exist')
    assert(#data.self.screens == 2, 'should have 2 screens')
    assert(data.self.screens[1].left == 100, 'first screen left should be 100')
    assert(data.self.screens[1].top == 50, 'first screen top should be 50')
    assert(data.self.screens[1].width == 640, 'first screen width should be 640')
    assert(data.self.screens[1].height == 360, 'first screen height should be 360')
end

function test_bug_255_ncl_include_custom_screens()
    local game_code = [[
        local P = {
            title = 'Test Game',
            version = '1.0.0',
            author = 'Test Author',
            screens = {
                {left=100, top=50, width=640, height=360},
                {left=200, top=100, width=800, height=600}
            }
        }
        return P
    ]]

    local ncl_template_file = io.open('ee/engine/meta/ginga/ncl.mustache', 'r')
    assert(ncl_template_file ~= nil, 'NCL template file should exist')
    local ncl_template = ncl_template_file:read('*a')
    ncl_template_file:close()

    local args = {core = 'ncl', ['non-relative'] = true}
    local rendered = cli_meta.render(game_code, ncl_template, args)

    assert(rendered ~= nil, 'rendered NCL should not be nil')

    assert(rendered:find('<property name="screen_100_50_640_360"/>') ~= nil, 'NCL should contain property for custom screen 1 (100,50,640,360)')
    assert(rendered:find('<property name="screen_200_100_800_600"/>') ~= nil, 'NCL should contain property for custom screen 2 (200,100,800,600)')

    assert(rendered:find('interface="screen_100_50_640_360"') ~= nil, 'NCL should contain link interface for custom screen 1')
    assert(rendered:find('interface="screen_200_100_800_600"') ~= nil, 'NCL should contain link interface for custom screen 2')

    assert(rendered:find('value="100, 50, 640, 360"') ~= nil, 'NCL should contain correct bounds values for custom screen 1')
    assert(rendered:find('value="200, 100, 800, 600"') ~= nil, 'NCL should contain correct bounds values for custom screen 2')
end

function test_bug_255_ncl_includes_default_screens()
    local game_code = [[
        local P = {
            title = 'Test Game',
            version = '1.0.0'
        }
        return P
    ]]

    local ncl_template_file = io.open('ee/engine/meta/ginga/ncl.mustache', 'r')
    assert(ncl_template_file ~= nil, 'NCL template file should exist')
    local ncl_template = ncl_template_file:read('*a')
    ncl_template_file:close()

    local args = {core = 'ncl', ['non-relative'] = true}
    local rendered = cli_meta.render(game_code, ncl_template, args)

    assert(rendered:find('<property name="screen_0_0_1280_720"/>') ~= nil, 'NCL should contain default screen 1280x720')
    assert(rendered:find('<property name="screen_0_0_1024_576"/>') ~= nil, 'NCL should contain default screen 1024x576')
end

test.unit(_G)
