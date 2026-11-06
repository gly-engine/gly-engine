local png_validator = require('source/shared/image/check_png')
local zcis_sheets = require('ee/engine/core/bind/ginga/draw_image_zcis')
local create_counter = require('source/shared/functional/counter')
local engine_draw_img = require('source/engine/api/draw/image')

local next_id, clear_id, clear_all, reserve_ids = create_counter()
local image_ids = {}
local image_count = {}
local image_error = {}
local image_canvas = {}
local image_base = {}
local image_index = {}

local sheets

local function canonical(src)
    local key = tostring(src)
    if type(src) ~= 'string' or not src:find('^https?://') then
        return key
    end
    if src:find('^https://') then
        return key, nil, 'HTTPS is not supported!'
    end
    return key, key
end

local function alias_id(key)
    local id = key:match('^id://(%d+)$')
    if id then
        id = tonumber(id)
        image_ids[key] = id
    end
    return id
end

local function id_of(base, index)
    local first = image_ids[base]
    return first and index < image_count[base] and first + index
end

local function load_sheet(std, base, count)
    local first = image_ids[base]
    if first then
        return first, image_canvas[first + image_count[base] - 1] ~= nil
    end

    local refusal = not std.http and 'remote images need http'
    local ready = not refusal
    local at = 0

    first = count > 1 and reserve_ids(count) or next_id()
    image_ids[base] = first
    image_count[base] = count

    while at < count do
        local id = first + at
        image_base[id] = base
        image_index[id] = at
        if refusal then
            image_error[id] = refusal
        else
            image_canvas[id], image_error[id] = sheets.want(base, at)
            ready = ready and image_canvas[id] ~= nil
        end
        at = at + 1
    end

    return first, ready
end

local function on_ready(base, index, texture)
    local id = id_of(base, index)
    if id then
        image_canvas[id] = texture
    end
end

local function on_failed(base, index, message)
    local id = id_of(base, index)
    if id then
        image_canvas[id] = nil
        image_error[id] = message
    end
end

local function image_load(std, canvas)
    return function(src, count)
        if src == nil then
            return nil, false
        end
        if type(src) == 'number' then
            return src, image_canvas[src] ~= nil
        end

        local key, base, refusal = canonical(src)
        if base then
            return load_sheet(std, base, count and count > 1 and count or 1)
        end

        local id = image_ids[key] or alias_id(key)
        if id then
            return id, image_canvas[id] ~= nil
        end

        id = next_id()
        image_ids[key] = id
        image_count[key] = 1
        image_base[id] = key
        image_index[id] = 0

        if refusal then
            image_error[id] = refusal
            return id, false
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
    if src == nil then
        return false
    end
    local key = canonical(src)
    return image_ids[key] or alias_id(key)
end

local function get_image_error(src)
    local id = image_id(src)
    return id and image_error[id]
end

local function image_unload(src)
    local id = image_id(src)
    local base = id and image_base[id]
    if base then
        local index = image_index[id]
        sheets.release(base, index)
        if index == 0 then
            image_ids[base] = nil
            image_count[base] = nil
        end
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
    image_count = {}
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
