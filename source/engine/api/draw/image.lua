local function image_draw(func, engine)
    return function(src, pos_x, pos_y)
        local x = engine.offset_x + (pos_x or 0)
        local y = engine.offset_y + (pos_y or 0)
        func(src, x, y)
    end  
end

local function image_mensure(func)
    return function(src)
        return func(src)
    end
end

local function image_load(func)
    return function(src, url_wip)
        return func(src, url_wip)
    end
end

local function image_exists(func)
    return function(src)
        return not not func(src)
    end
end

local function image_unload(func)
    return function(src)
        return func(src)
    end
end

local function image_unload_all(func)
    return function(src)
        return func(src)
    end
end

local function install(std, engine, func)
    local f = func.unload or function() end
    std.image.load = image_load(func.load)
    std.image.draw = image_draw(func.draw, engine)
    std.image.exists = image_exists(func.load)
    std.image.mensure = image_mensure(func.mensure)
    std.image.unload = image_unload(func.unload or f)
    std.image.unload_all = image_unload_all(func.unload_all or f)
    std.image.mensure_width = function(v) return select(1, std.image.mensure(v)) end
    std.image.mensure_height = function(v) return select(2, std.image.mensure(v)) end
end

return {
    install = install
}
