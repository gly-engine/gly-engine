local png_validator = require('source/shared/image/check_png')
local zcis_sheets = require('ee/engine/core/bind/ginga/draw_image_zcis')
local create_counter = require('source/shared/functional/counter')
local engine_draw_img = require('source/engine/api/draw/image')

local next_id, clear_id, clear_all = create_counter()
local image_ids = {}
local image_keys = {}
local image_error = {}
local image_canvas = {}
local image_base = {}
local image_index = {}
local sheets

local function key_of(base, index)
    return base..'#index='..index
end

local function canonical(src)
    local key = tostring(src)
    if type(src) ~= 'string' or not src:find('^https?://') then
        return key
    end

    local base, fragment = key:match('^([^#]*)#(.*)$')
    if not base then
        return key_of(key, 0), key, 0
    end

    local index = fragment:match('^index=(%d+)$')
    if not index then
        return key, nil, nil, 'invalid image fragment: '..fragment
    end

    index = tonumber(index)
    return key_of(base, index), base, index
end

local function on_ready(base, index, texture)
    local id = image_ids[key_of(base, index)]
    if id then
        image_canvas[id] = texture
    end
end

local function on_failed(base, index, message)
    local id = image_ids[key_of(base, index)]
    if id then
        image_canvas[id] = nil
        image_error[id] = message
    end
end

local function image_load(std, canvas)
    return function(src)
        if src == nil then
            return nil, false
        end
        if type(src) == 'number' then
            return src, image_canvas[src] ~= nil
        end

        local key, base, index, refusal = canonical(src)
        local id = image_ids[key]
        if id then
            return id, image_canvas[id] ~= nil
        end

        id = next_id()
        image_ids[key] = id
        image_keys[id] = key

        if refusal then
            image_error[id] = refusal
            return id, false
        end

        if base then
            if not std.http then
                image_error[id] = 'remote images need http'
                return id, false
            end
            image_base[id] = base
            image_index[id] = index
            image_canvas[id], image_error[id] = sheets.want(base, index)
            return id, image_canvas[id] ~= nil
        end

        if type(src) ~= 'userdata' then
            local valid, message = png_validator.check_error(src)
            if not valid then
                image_error[id] = message or 'invalid png'
                return id, false
            end
        end

        local ok, texture, message = pcall(canvas.new, canvas, src)
        if not ok or not texture then
            image_error[id] = ok and message or texture
            return id, false
        end

        image_canvas[id] = texture
        return id, true
    end
end

local function image_draw(canvas, load)
    return function(src, pos_x, pos_y)
        local id = load(src)
        local image = id and image_canvas[id]
        if image then
            canvas:compose(pos_x, pos_y, image)
        end
    end
end

local function image_mensure(load)
    return function(src)
        local id = load(src)
        local image = id and image_canvas[id]
        if image then
            return image:attrSize()
        end
        return 0, 0
    end
end

local function image_exists(load)
    return function(src)
        local _, loaded = load(src)
        return loaded
    end
end

local function image_id(src)
    if type(src) == 'number' then
        return src
    end
    return src ~= nil and image_ids[(canonical(src))]
end

local function get_image_error(src)
    local id = image_id(src)
    return id and image_error[id]
end

local function image_unload(src)
    local id = image_id(src)
    local key = id and image_keys[id]
    if key then
        if image_base[id] then
            sheets.release(image_base[id], image_index[id])
        end
        image_ids[key] = nil
        image_keys[id] = nil
        image_canvas[id] = nil
        image_error[id] = nil
        image_base[id] = nil
        image_index[id] = nil
        clear_id(id)
    end
end

local function image_unload_all()
    sheets.clear()
    image_ids = {}
    image_keys = {}
    image_canvas = {}
    image_error = {}
    image_base = {}
    image_index = {}
    clear_all()
end

local function install(std, engine)
    local load = image_load(std, engine.canvas)
    sheets = zcis_sheets.create(std, engine.canvas, {ready = on_ready, failed = on_failed})
    std.bus.listen('loop', sheets.process)
    engine_draw_img.install(std, engine, {
        load = load,
        draw = image_draw(engine.canvas, load),
        exists = image_exists(load),
        mensure = image_mensure(load),
        error = get_image_error,
        unload = image_unload,
        unload_all = image_unload_all
    })
end

return {
    install = install
}
