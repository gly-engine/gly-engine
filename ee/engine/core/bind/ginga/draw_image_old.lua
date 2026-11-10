local png_validator = require('source/shared/image/check_png')
local creater_counter = require('source/shared/functional/counter')

local nextId, clearId, clearAll = creater_counter()

local image_ids = {}
local image_canvas = {}

local function load_png(std, engine, canvas, src)
    local is_userdata = type(src) == 'userdata'
    local key = src and tostring(src)
    if not key or #key == 0 then return false end

    local id = image_ids[key]
    if id then return image_canvas[id] end

    if not is_userdata and not png_validator.check_error(src) then return false end
    local ok, texture = pcall(canvas.new, canvas, src)
    if not ok or not texture then return false end

    id = nextId()
    image_ids[key] = id
    image_canvas[id] = texture
    return texture
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
        return 0, 0
    end
end

local function image_exists(std, engine, canvas)
    return function(src)
        return not not load_png(std, engine, canvas, src)
    end
end

local function image_unload(src)
    local key = tostring(src)
    local id = image_ids[key]
    if id then
        image_ids[key] = nil
        image_canvas[id] = nil
        clearId(id)
    end
end

local function image_unload_all()
    image_ids = {}
    image_canvas = {}
    clearAll()
end

local function install(std, engine)
    std.image.draw = image_draw(std, engine, engine.canvas)
    std.image.exists = image_exists(std, engine, engine.canvas)
    std.image.mensure = image_mensure(std, engine, engine.canvas)
    std.image.unload = image_unload
    std.image.unload_all = image_unload_all
end

return {
    install = install
}
