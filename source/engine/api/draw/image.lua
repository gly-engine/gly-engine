local image_ids = {}

local function image_id(src, id)
    if type(src) == 'string' then 
        image_ids[src] = id or false
    end
    return id
end

local function image_draw(func, engine)
    return function(src, pos_x, pos_y)
        local x = engine.offset_x + (pos_x or 0)
        local y = engine.offset_y + (pos_y or 0)
        image_id(src, func(src, x, y))
    end  
end

local function image_mensure(func)
    return function(src)
        return func(src)
    end
end

local function image_exists(func)
    return function(src)
        return not not image_id(src, func())
    end
end

local function image_load(func)
    return function(src)
        return image_id(src, func())
    end
end

local function image_unload(func)
    return function(src)
        local id = type(src) == 'string' and image_ids[src]
        if func(id or src) then
            image_ids[src] = nil
        end
    end
end

local function image_unload_all(func)
    return function()
        for src, id in pairs(image_ids) do
            if func(id or src) then
                image_ids[src] = nil
            end
        end
    end
end

local function install(std, engine, func)
    local unload = func.unload or function() end
    std.image.load = image_load(func.load)
    std.image.draw = image_draw(func.draw, engine)
    std.image.exists = image_exists(func.load)
    std.image.mensure = image_mensure(func.mensure)
    std.image.mensure_width = function(v) return select(1, std.image.mensure(v)) end
    std.image.mensure_height = function(v) return select(2, std.image.mensure(v)) end
    std.image.unload = image_unload(unload)
    std.image.unload_all = image_unload_all(unload)
end

return {
    install = install
}
