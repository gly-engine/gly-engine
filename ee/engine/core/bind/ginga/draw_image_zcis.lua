local zcis_decoder = require('source/shared/image/decoder_zcis')
local cobs = require('source/shared/string/encode/cobs')

local ignore = function() end

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

local function out_of_range(count, index)
    return 'zcis has '..count..' cuts, no index '..index
end

local function whole_canvas(decoder, cut)
    return #decoder.cuts == 1 and cut.x == 0 and cut.y == 0
        and cut.width == decoder.width and cut.height == decoder.height
end

local function create(std, canvas, handlers)
    local sheets = {}
    local decoder_queue = {}
    local decoder_cursor = 1
    local remote_queue = {}
    local remote_head = 1
    local remote_tail = 0
    local remote_active = false
    local self = {}

    local function finish_request(sheet)
        if sheet.started and not sheet.finished then
            sheet.finished = true
            remote_active = false
        end
    end

    local function cancel_request(sheet)
        local request = sheet.request
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

    local function remove_decoder(sheet)
        local state = sheet.state
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

    local function drop_sheet(sheet)
        if sheets[sheet.base] == sheet then
            sheets[sheet.base] = nil
        end
        cancel_request(sheet)
        remove_decoder(sheet)
    end

    local function carve(sheet, decoder)
        local ready = decoder:take_ready()
        for at = 1, #ready do
            local order = ready[at]
            local cut = decoder.cuts[order]
            local index = order - 1
            local target = sheet.carved[index]

            if not target then
                target = whole_canvas(decoder, cut) and decoder.canvas
                    or canvas.new(canvas, cut.width, cut.height)
                sheet.carved[index] = target
            end
            if target ~= decoder.canvas then
                target:compose(-cut.x, -cut.y, decoder.canvas)
            end
            if sheet.wanted[index] then
                handlers.ready(sheet.base, index, target)
            end
        end
    end

    local function fail_sheet(sheet, message)
        cancel_request(sheet)
        remove_decoder(sheet)
        sheet.carved = {}
        sheet.error = message
        for index in pairs(sheet.wanted) do
            handlers.failed(sheet.base, index, message)
        end
    end

    local function load_remote(sheet)
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
            sheet.count = #decoder.cuts
            for index in pairs(sheet.wanted) do
                if index >= sheet.count then
                    handlers.failed(sheet.base, index, out_of_range(sheet.count, index))
                end
            end
            add_decoder(sheet, decoder)
        end

        local request = std.http.get(sheet.base)
        sheet.request = request
        request
            :success(finish)
            :failed(set_error)
            :error(set_error)
            :run()
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
                load_remote(sheet)
                return
            end
        end

        remote_queue = {}
        remote_head = 1
        remote_tail = 0
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
            carve(sheet, state.decoder)
        end
        if not ok then
            fail_sheet(sheet, done)
        elseif done then
            remove_decoder(sheet)
            finish_request(sheet)
            state.decoder:close()
            sheet.done = true
        else
            decoder_cursor = decoder_cursor == #decoder_queue and 1 or decoder_cursor + 1
        end
    end

    function self.want(base, index)
        local sheet = sheets[base]
        if sheet and sheet.count and index >= sheet.count then
            return nil, out_of_range(sheet.count, index)
        end
        if sheet and sheet.done and not sheet.carved[index] then
            drop_sheet(sheet)
            sheet = nil
        end
        if not sheet then
            sheet = {base = base, wanted = {}, carved = {}}
            sheets[base] = sheet
            remote_tail = remote_tail + 1
            remote_queue[remote_tail] = sheet
        end

        sheet.wanted[index] = true
        return sheet.carved[index], sheet.error
    end

    function self.release(base, index)
        local sheet = sheets[base]
        if not sheet then return end

        sheet.wanted[index] = nil
        sheet.carved[index] = nil
        if next(sheet.wanted) == nil then
            drop_sheet(sheet)
        end
    end

    function self.process()
        process_requests()
        process_decoders()
    end

    function self.clear()
        for _, sheet in pairs(sheets) do
            cancel_request(sheet)
        end
        sheets = {}
        decoder_queue = {}
        decoder_cursor = 1
        remote_queue = {}
        remote_head = 1
        remote_tail = 0
        remote_active = false
    end

    return self
end

return {
    create = create
}
