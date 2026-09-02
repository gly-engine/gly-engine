local png_validator = require('source/shared/image/check_png')
local zcis_decoder = require('source/shared/image/decoder_zcis')
local create_counter = require('source/shared/functional/counter')

local next_id, clear_id, clear_all = create_counter()
local image_ids = {}
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
        request.stream = nil
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

local function make_canvas_ops(canvas)
    return {
        start = function(width, height)
            return canvas.new(canvas, width, height)
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

    local ok, done = pcall(state.decoder.step, state.decoder, 2048)
    if ok and state.decoder.canvas then
        image_canvas[id] = state.decoder.canvas
    end
    if not ok then
        remove_decoder(id)
        image_canvas[id] = nil
        if state.token.request then
            state.token.decode_error = done
            state.token.request.stream = nil
        else
            image_request[id] = nil
            finish_request(state.token)
            image_error[id] = done
        end
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
    local decoder = zcis_decoder.stream(make_canvas_ops(canvas))
    local streamed = false
    local stream_error
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

    local function publish()
        if not is_active() or token.decode_error then return end
        if decoder.canvas then
            image_canvas[id] = decoder.canvas
        end
        if not image_decoder[id] then
            add_decoder(id, decoder, token)
        end
    end

    local function stream(data)
        if not is_active() or token.decode_error then return end
        streamed = true
        local ok, message = pcall(decoder.push, decoder, data)
        if not ok then
            stream_error = message
            request.stream = nil
            remove_decoder(id)
            image_canvas[id] = nil
            return
        end
        publish()
    end

    local function set_error(http_std)
        fail(http_std.http.error or tostring(http_std.http.status))
    end

    local function finish(http_std)
        if not is_active() then return end
        if stream_error then
            fail(stream_error)
            return
        end
        if token.decode_error then
            fail(token.decode_error)
            return
        end

        local ok, message
        if streamed then
            ok, message = pcall(decoder.finish, decoder)
        else
            ok, message = pcall(zcis_decoder.new, http_std.http.body, make_canvas_ops(canvas))
            if ok then
                decoder = message
            end
        end
        if not ok then
            fail(message)
            return
        end
        token.request = nil
        publish()
    end

    request = std.http.get(src)
    token.request = request
    request.stream = stream
    request.discard_body = true
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

        local key = tostring(src)
        local id = image_ids[key]
        if id then
            return id, image_canvas[id] ~= nil
        end

        id = next_id()
        image_ids[key] = id

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

        if not is_userdata and not png_validator.check_error(src) then
            image_error[id] = 'invalid png'
            return id, false
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

local function image_draw(engine, canvas, load)
    return function(src, pos_x, pos_y)
        local id = load(src)
        local image = id and image_canvas[id]
        if image then
            local x = engine.offset_x + (pos_x or 0)
            local y = engine.offset_y + (pos_y or 0)
            canvas:compose(x, y, image)
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

local function get_image_error(src)
    local id = image_ids[tostring(src)]
    return id and image_error[id]
end

local function image_unload(src)
    local key = tostring(src)
    local id = image_ids[key]
    if id then
        cancel_request(image_request[id])
        image_ids[key] = nil
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
    std.image.load = load
    std.image.draw = image_draw(engine, engine.canvas, load)
    std.image.exists = image_exists(load)
    std.image.mensure = image_mensure(load)
    std.image.error = get_image_error
    std.image.unload = image_unload
    std.image.unload_all = image_unload_all
end

return {
    install = install
}
