local ui_jsx = require('source/engine/api/draw/ui/jsx')
local ui_grid = require('source/engine/api/draw/ui/grid')
local ui_slide = require('source/engine/api/draw/ui/slide')
local ui_style = require('source/engine/api/draw/ui/style')
local util_decorator = require('source/shared/functional/decorator')

local function install(std, engine, application)
    std.ui = std.ui or {}
    std.h = util_decorator.prefix2(std, engine, ui_jsx.h)
    std.ui.grid = util_decorator.prefix2(std, engine, ui_grid.component)
    std.ui.slide = util_decorator.prefix2(std, engine, ui_slide.component)
    std.ui.style = util_decorator.prefix1(engine, ui_style.component)
end

local P = {
    install=install
}

return P
