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
local image_sheet = {}
local image_index = {}
local sheets = {}
local decoder_queue = {}
local decoder_cursor = 1
local ignore = function() end
local remote_queue = {}
local remote_head = 1
local remote_tail = 0
local remote_active = false

local function finish_request(sheet)
    if sheet and sheet.started and not sheet.finished then
        sheet.finished = true
        remote_active = false
    end
end

local function cancel_request(sheet)
    local request = sheet and sheet.request
    if request then
        request.success_handler = ignore
        request.failed_handler = ignore
        request.error_handler = ignore
        if request.cancel then
            request.cancel()
        end
        sheet.request = nil
    end
    finish_request(sheet)
end

local function canonical(src)
    local key = tostring(src)
    if type(src) ~= 'string' or not src:find('^https?://') then
        return key
    end

    local base, fragment = key:match('^([^#]*)#(.*)$')
    if not base then
        return key..'#index=0', key, 0
    end

    local index = fragment:match('^index=(%d+)$')
    if not index then
        return key, nil, nil, 'invalid image fragment: '..fragment
    end

    index = tonumber(index)
    return base..'#index='..index, base, index
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
local function remove_decoder(sheet)
    local state = sheet and sheet.state
    if not state then return end

    local index = state.index
    local last = decoder_queue[#decoder_queue]
    decoder_queue[index] = last
    if last then
        last.index = index
    end
    decoder_queue[#decoder_queue] = nil
    sheet.state = nil
    if decoder_cursor > #decoder_queue then
        decoder_cursor = 1
    end
end

local function add_decoder(sheet, decoder)
    local state = {
        sheet = sheet,
        decoder = decoder,
        index = #decoder_queue + 1
    }
    sheet.state = state
    decoder_queue[state.index] = state
end

local function publish(sheet, canvas)
    sheet.canvas = canvas
    for _, id in pairs(sheet.ids) do
        image_canvas[id] = canvas
    end
end

local function fail_sheet(sheet, message)
    cancel_request(sheet)
    remove_decoder(sheet)
    sheet.canvas = nil
    sheet.error = message
    for _, id in pairs(sheet.ids) do
        image_canvas[id] = nil
        image_error[id] = message
    end
end

local function process_decoders()
    if #decoder_queue == 0 then return end
    if decoder_cursor > #decoder_queue then
        decoder_cursor = 1
    end

    local state = decoder_queue[decoder_cursor]
    local sheet = state.sheet
    if sheets[sheet.base] ~= sheet then
        remove_decoder(sheet)
        return
    end

    local ok, done = pcall(state.decoder.step_commit, state.decoder)
    if ok and state.decoder.canvas and state.decoder.commits > 0 then
        publish(sheet, state.decoder.canvas)
    end
    if not ok then
        fail_sheet(sheet, done)
    elseif done then
        remove_decoder(sheet)
        finish_request(sheet)
        publish(sheet, state.decoder:close())
    else
        decoder_cursor = decoder_cursor == #decoder_queue and 1 or decoder_cursor + 1
    end
end

local function process_requests()
    if remote_active then return end

    while remote_head <= remote_tail do
        local sheet = remote_queue[remote_head]
        remote_queue[remote_head] = nil
        remote_head = remote_head + 1
        if sheets[sheet.base] == sheet then
            remote_active = true
            sheet.started = true
            sheet.start()
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

local function load_remote(std, canvas, sheet)
    local function is_active()
        return sheets[sheet.base] == sheet
    end

    local function fail(message)
        if not is_active() then return end
        fail_sheet(sheet, message)
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

        sheet.request = nil
        add_decoder(sheet, decoder)
    end

    local request = std.http.get(with_cobs(sheet.base))
    sheet.request = request
    request
        :success(finish)
        :failed(set_error)
        :error(set_error)
        :run()
end

local function join_sheet(std, canvas, base, index, id)
    local sheet = sheets[base]
    if not sheet then
        sheet = {base = base, ids = {}}
        sheet.start = function()
            load_remote(std, canvas, sheet)
        end
        sheets[base] = sheet
        remote_tail = remote_tail + 1
        remote_queue[remote_tail] = sheet
    end

    sheet.ids[index] = id
    image_sheet[id] = sheet
    image_index[id] = index
    image_canvas[id] = sheet.canvas
    image_error[id] = sheet.error
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
            join_sheet(std, canvas, base, index, id)
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
        local sheet = image_sheet[id]
        if sheet then
            sheet.ids[image_index[id]] = nil
            if next(sheet.ids) == nil then
                sheets[sheet.base] = nil
                cancel_request(sheet)
                remove_decoder(sheet)
            end
        end
        image_ids[key] = nil
        image_keys[id] = nil
        image_canvas[id] = nil
        image_error[id] = nil
        image_sheet[id] = nil
        image_index[id] = nil
        clear_id(id)
    end
end

local function image_unload_all()
    for _, sheet in pairs(sheets) do
        cancel_request(sheet)
    end
    image_ids = {}
    image_keys = {}
    image_canvas = {}
    image_error = {}
    image_sheet = {}
    image_index = {}
    sheets = {}
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
