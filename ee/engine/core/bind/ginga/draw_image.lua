local png_validator = require('source/shared/image/check_png')
local zcis_decoder = require('source/shared/image/decoder_zcis')
local create_counter = require('source/shared/functional/counter')
local engine_draw_img = require('source/engine/api/draw/image')
local cobs = require('source/shared/string/encode/cobs')

local next_id, clear_id, clear_all = create_counter()
local image_ids = {}
local image_keys = {}
local image_error = {}
local image_canvas = {}
local image_request = {}
local image_decoder = {}
local decoder_queue = {}
local decoder_cursor = 1
local ignore = function() end
local remote_queue = {}
local remote_head = 1
local remote_tail = 0
local remote_active = false

local function finish_request(token)
    if token and token.started and not token.finished then
        token.finished = true
        remote_active = false
    end
end

local function cancel_request(token)
    local request = token and token.request
    if request then
        request.success_handler = ignore
        request.failed_handler = ignore
        request.error_handler = ignore
        if request.cancel then
            request.cancel()
        end
        token.request = nil
    end
    finish_request(token)
end

local function with_cobs(src)
    if not src:find('[?&]format=zcis') or src:find('[?&]encoding=') then
        return src
    end
    return src..'&encoding=cobs'
end

local function is_cobs(headers)
    for name, value in pairs(headers or {}) do
        if string.lower(name) == 'x-encoding' then
            return string.lower(tostring(value)) == 'cobs'
        end
    end
    return false
end

local function content_type(headers)
    for name, value in pairs(headers or {}) do
        if string.lower(name) == 'content-type' then
            return string.lower(tostring(value)):match('^%s*([^;%s]+)')
        end
    end
end

local function unsupported_format(headers, body)
    local kind = content_type(headers)
    if kind and kind:find('^image/') and not kind:find('zcis') then
        return 'remote '..kind:sub(7)..' not supported, use format=zcis'
    end
    if body:sub(1, 8) ~= '!<arch>\n' then
        return 'remote image must be zcis'
    end
end

local function make_canvas_ops(canvas)
    return {
        start = function(width, height)
            local target = canvas.new(canvas, width, height)
            return target, target.pixel
        end,
        color = function(target, r, g, b, a)
            target:attrColor(r, g, b, a)
        end,
        pixel = function(target, x, y, width, height)
            target:drawRect('fill', x, y, width, height)
        end,
        commit = function(target)
            target:flush()
        end
    }
end
local function remove_decoder(id)
    local state = image_decoder[id]
    if not state then return end

    local index = state.index
    local last = decoder_queue[#decoder_queue]
    decoder_queue[index] = last
    if last then
        last.index = index
    end
    decoder_queue[#decoder_queue] = nil
    image_decoder[id] = nil
    if decoder_cursor > #decoder_queue then
        decoder_cursor = 1
    end
end

local function add_decoder(id, decoder, token)
    local state = {
        id = id,
        decoder = decoder,
        token = token,
        index = #decoder_queue + 1
    }
    image_decoder[id] = state
    decoder_queue[state.index] = state
end

local function process_decoders()
    if #decoder_queue == 0 then return end
    if decoder_cursor > #decoder_queue then
        decoder_cursor = 1
    end

    local state = decoder_queue[decoder_cursor]
    local id = state.id
    if image_request[id] ~= state.token then
        remove_decoder(id)
        return
    end

    local ok, done = pcall(state.decoder.step_commit, state.decoder)
    if ok and state.decoder.canvas and state.decoder.commits > 0 then
        image_canvas[id] = state.decoder.canvas
    end
    if not ok then
        remove_decoder(id)
        image_canvas[id] = nil
        image_request[id] = nil
        finish_request(state.token)
        image_error[id] = done
    elseif done then
        remove_decoder(id)
        finish_request(state.token)
        image_request[id] = nil
        image_canvas[id] = state.decoder:close()
    else
        decoder_cursor = decoder_cursor == #decoder_queue and 1 or decoder_cursor + 1
    end
end

local function process_requests()
    if remote_active then return end

    while remote_head <= remote_tail do
        local state = remote_queue[remote_head]
        remote_queue[remote_head] = nil
        remote_head = remote_head + 1
        if image_request[state.id] == state.token then
            remote_active = true
            state.token.started = true
            state.start()
            return
        end
    end

    remote_queue = {}
    remote_head = 1
    remote_tail = 0
end

local function process_images()
    process_requests()
    process_decoders()
end

local function load_remote(std, canvas, id, src, token)
    local request

    local function is_active()
        return image_request[id] == token
    end

    local function fail(message)
        if not is_active() then return end
        cancel_request(token)
        image_request[id] = nil
        remove_decoder(id)
        image_canvas[id] = nil
        image_error[id] = message
    end

    local function set_error(http_std)
        fail(http_std.http.error or tostring(http_std.http.status))
    end

    local function finish(http_std)
        if not is_active() then return end

        local body = http_std.http.body or ''
        local headers = http_std.http.headers
        if is_cobs(headers) then
            local ok, message = pcall(cobs.decode, body)
            if not ok then
                fail(message)
                return
            end
            body = message
        end

        local message = unsupported_format(headers, body)
        if message then
            fail(message)
            return
        end

        local ok, decoder = pcall(zcis_decoder.new, body, make_canvas_ops(canvas))
        if not ok then
            fail(decoder)
            return
        end

        token.request = nil
        add_decoder(id, decoder, token)
    end

    request = std.http.get(with_cobs(src))
    token.request = request
    request
        :success(finish)
        :failed(set_error)
        :error(set_error)
        :run()
end

local function image_load(std, canvas)
    return function(src)
        if src == nil then
            return nil, false
        end
        if type(src) == 'number' then
            return src, image_canvas[src] ~= nil
        end

        local key = tostring(src)
        local id = image_ids[key]
        if id then
            return id, image_canvas[id] ~= nil
        end

        id = next_id()
        image_ids[key] = id
        image_keys[id] = key

        local is_userdata = type(src) == 'userdata'
        local is_remote = type(src) == 'string' and src:find('^https?://') ~= nil
        if is_remote then
            if not std.http then
                image_error[id] = 'remote images need http'
                return id, false
            end
            local token = {}
            image_request[id] = token
            remote_tail = remote_tail + 1
            remote_queue[remote_tail] = {
                id = id,
                token = token,
                start = function()
                    load_remote(std, canvas, id, src, token)
                end
            }
            return id, false
        end

        if not is_userdata then
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
    return src ~= nil and image_ids[tostring(src)]
end

local function get_image_error(src)
    local id = image_id(src)
    return id and image_error[id]
end

local function image_unload(src)
    local id = image_id(src)
    local key = id and image_keys[id]
    if key then
        cancel_request(image_request[id])
        image_ids[key] = nil
        image_keys[id] = nil
        image_canvas[id] = nil
        image_error[id] = nil
        image_request[id] = nil
        remove_decoder(id)
        clear_id(id)
    end
end

local function image_unload_all()
    for _, token in pairs(image_request) do
        cancel_request(token)
    end
    image_ids = {}
    image_keys = {}
    image_canvas = {}
    image_error = {}
    image_request = {}
    image_decoder = {}
    decoder_queue = {}
    decoder_cursor = 1
    remote_queue = {}
    remote_head = 1
    remote_tail = 0
    remote_active = false
    clear_all()
end

local function install(std, engine)
    local load = image_load(std, engine.canvas)
    std.bus.listen('loop', process_images)
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