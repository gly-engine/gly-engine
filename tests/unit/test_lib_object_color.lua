local test = require('tests/framework/microtest')
local zeebo_color = require('source/engine/api/system/color')

local std = {}
zeebo_color.install(std)

function test_color_install()
    assert(std.color.white == 0xFFFFFFFF)
end

test.unit(_G)
