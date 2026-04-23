local png_validator = require('source/shared/image/check_png')

local function load_png(std, engine, src)
    local is_userdata = type(src) == 'userdata'
    local key = src and tostring(src)
    if not key or #key == 0 then return false end
    return std.mem.cache('image'..key, function()
        if not is_userdata and not png_validator.check_error(src) then return false end
        local ok, texture = pcall(engine.canvas.new, engine.canvas, src)
        return (ok and texture) or false
    end)
end

local function image_draw(std, engine)
    return function(src, pos_x, pos_y)
        local image = load_png(std, engine, src)
        if image then
            local x = engine.offset_x + (pos_x or 0)
            local y = engine.offset_y + (pos_y or 0)
            local pip = engine.pip
            if pip then
                engine.canvasgly[1]:compose(x, y, image)
                engine.canvasgly[2]:compose(x, -pip.y, image)
                engine.canvasgly[3]:compose(-(pip.x + pip.w), -pip.y, image)
                engine.canvasgly[4]:compose(0, -(pip.y + pip.h), image)
            else
                engine.canvas:compose(x, y, image)
            end
        end
    end  
end

local function image_mensure(std, engine)
    return function(src)
        local image = load_png(std, engine, src)
        if image then
            local w, h = image:attrSize()
            return w, h
        end
        return nil
    end
end

local function image_exists(std, engine)
    return function(src)
        return not not load_png(std, engine, src)
    end
end

local function install(std, engine)
    std.image.draw = image_draw(std, engine)
    std.image.exists = image_exists(std, engine)
    std.image.mensure = image_mensure(std, engine)
    --! @todo
    std.image.unload = function() end
    std.image.unload_all = function() end
    std.image.mensure_width = function(v) return select(1, std.image.mensure(v)) end
    std.image.mensure_height = function(v) return select(2, std.image.mensure(v)) end
end

return {
    install = install
}