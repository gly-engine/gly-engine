local math = require('math')
local ui_grid = require('src/lib/engine/draw/ui/grid')
local ui_slide = require('src/lib/engine/draw/ui/slide')
local ui_style = require('src/lib/engine/draw/ui/style')
local util_decorator = require('src/lib/util/decorator')

local function install(std, engine, application)
    std.ui = std.ui or {}
    std.ui.grid = util_decorator.prefix2(std, engine, ui_grid.component)
    std.ui.slide = util_decorator.prefix2(std, engine, ui_slide.component)
    std.ui.style = util_decorator.prefix2(std, engine, ui_style.component)
end

local P = {
    install=install
}

return P
