local png_validator = require('source/shared/image/check_png')

local function load_png(std, engine, canvas, src)
    if not src or #src == 0 then return false end
    return std.mem.cache('image'..src, function()
        if not png_validator.check_error(src) then return false end
        local ok, texture = pcall(canvas.new, canvas, src)
        return (ok and texture) or false
    end)
end

local function image_draw(std, engine, canvas)
    return function(src, pos_x, pos_y)
        local image = load_png(std, engine, canvas, src)
        if image then
            local x = engine.offset_x + (pos_x or 0)
            local y = engine.offset_y + (pos_y or 0)
            canvas:compose(x, y, image)
        end
    end  
end

local function image_mensure(std, engine, canvas)
    return function(src)
        local image = load_png(std, engine, canvas, src)
        if image then
            local w, h = image:attrSize()
            return w, h
        end
        return nil
    end
end

local function image_exists(std, engine, canvas)
    return function(src)
        return not not load_png(std, engine, canvas, src)
    end
end

local function install(std, engine)
    std.image.draw = image_draw(std, engine, engine.canvas)
    std.image.exists = image_exists(std, engine, engine.canvas)
    std.image.mensure = image_mensure(std, engine, engine.canvas)
end

return {
    install = install
}
