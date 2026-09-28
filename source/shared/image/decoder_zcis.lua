local math = require('math')
local string = require('string')
local ar = require('source/shared/archive/ar')
local ppm = require('source/shared/image/reader_ppm')
local pcx = require('source/shared/image/reader_pcx')
local yuv = require('source/shared/image/reader_yuv')

local floor = math.floor
local lower = string.lower
local base62 = {}
local alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

for index = 1, #alphabet do
    base62[alphabet:byte(index)] = index - 1
end

local function decode_pair(pair)
    local high = base62[pair:byte(1)]
    local low = base62[pair:byte(2)]
    if high == nil or low == nil then
        error('invalid zcis base62 value')
    end
    return high * 62 + low
end

local function parse_bounds(member)
    local header = member.body:sub(member.offset, member.offset + member.size - 1)
    local width = 0
    local height = 0
    local count = 0

    for line in header:gmatch('[^\r\n]+') do
        local x, y, w, h = line:match('^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)$')
        x = tonumber(x)
        y = tonumber(y)
        w = tonumber(w)
        h = tonumber(h)
        if not x or not y or not w or not h or x > 3843 or y > 3843 or w <= 0 or w > 3843 or h <= 0 or h > 3843 then
            error('invalid zcis image bounds')
        end
        width = math.max(width, x + w)
        height = math.max(height, y + h)
        count = count + 1
    end

    if count == 0 then
        error('empty zcis header')
    end
    return width, height
end

local function parse_chunk(member, atlas_width, atlas_height)
    local command, x, y, width, height, extension = member.name:match(
        '^[0-9A-Za-z]([a-eA-E])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])([0-9A-Za-z][0-9A-Za-z])%.([0-9A-Za-z]+)$'
    )
    if not command then
        error('invalid zcis chunk name')
    end

    local chunk = {
        command = command,
        x = decode_pair(x),
        y = decode_pair(y),
        width = decode_pair(width),
        height = decode_pair(height),
        extension = lower(extension),
        member = member
    }
    if chunk.width <= 0 or chunk.height <= 0 or chunk.x + chunk.width > atlas_width or chunk.y + chunk.height > atlas_height then
        error('zcis chunk outside image bounds')
    end
    return chunk
end

local function make_reader(chunk)
    local member = chunk.member
    if chunk.extension == 'ppm' then
        return ppm.new(member.body, member.offset, member.size)
    elseif chunk.extension == 'yuv' then
        return yuv.raw(member.body, member.offset, member.size, chunk.width, chunk.height)
    elseif chunk.extension == 'y4m' then
        return yuv.y4m(member.body, member.offset, member.size)
    elseif chunk.extension == 'pcx' then
        return pcx.new(member.body, member.offset, member.size)
    end
    error('unsupported zcis chunk format: '..chunk.extension)
end

local function prepare_masks(masks, active_masks, y, start_x, step)
    local count = 0
    for index = 1, #masks do
        local mask = masks[index]
        local relative_y = y - mask.y
        if relative_y >= 0 and relative_y < mask.height then
            mask.source_y = mask.direct_height
                and relative_y
                or floor(relative_y * mask.reader.height / mask.height)
            if mask.reader.prepare and not mask.reader.prepare(mask.source_y, 2048) then
                return nil
            end

            local relative_x = start_x - mask.x
            if mask.direct_width then
                mask.source_x = relative_x
            else
                local scaled_x = relative_x * mask.reader.width
                mask.source_x = floor(scaled_x / mask.width)
                mask.source_error = scaled_x - mask.source_x * mask.width
                local delta = mask.reader.width * step
                mask.source_step = floor(delta / mask.width)
                mask.source_delta = delta - mask.source_step * mask.width
            end
            count = count + 1
            active_masks[count] = mask
        end
    end
    for index = count + 1, #active_masks do
        active_masks[index] = nil
    end
    return count
end

local function masked_alpha(active_masks, count, x, step, alpha)
    local result = alpha
    for index = 1, count do
        local mask = active_masks[index]
        if x >= mask.x and x < mask.x + mask.width
            and mask.reader.alpha(mask.source_x, mask.source_y) == 0 then
            result = 0
        end

        if mask.direct_width then
            mask.source_x = mask.source_x + step
        else
            mask.source_x = mask.source_x + mask.source_step
            mask.source_error = mask.source_error + mask.source_delta
            if mask.source_error >= mask.width then
                mask.source_x = mask.source_x + 1
                mask.source_error = mask.source_error - mask.width
            end
        end
    end
    return result
end

local function paint(ops, canvas, x, y, width, r, g, b, a)
    ops.color(canvas, r, g, b, a)
    ops.pixel(canvas, x, y, width, 1)
end

local function begin_row(self)
    local command = self.command
    if (command == 'c' or command == 'd') and self.target_y % 2 == 1 then
        return true
    end

    local chunk = self.chunk
    local reader = self.reader
    local step = (command == 'b' or command == 'd') and 2 or 1
    local direct_height = reader.height == chunk.height
    local absolute_y = chunk.y + self.target_y
    local active_count = prepare_masks(
        self.chunk_masks,
        self.active_masks,
        absolute_y,
        chunk.x,
        step
    )
    if not active_count then
        return nil
    end

    self.row_started = true
    self.row_step = step
    self.row_direct_width = reader.width == chunk.width
    self.row_source_y = direct_height
        and self.target_y
        or floor(self.target_y * reader.height / chunk.height)
    self.row_absolute_y = absolute_y
    self.row_active_count = active_count
    self.row_source_x = 0
    self.row_source_error = 0
    local delta = reader.width * step
    self.row_source_step = floor(delta / chunk.width)
    self.row_source_delta = delta - self.row_source_step * chunk.width
    self.row_target_x = 0
    self.row_run_x = nil
    return false
end

local function draw_pixels(self, budget)
    if not self.row_started then
        local skipped = begin_row(self)
        if skipped == nil then return 0, false end
        if skipped then return 1, true end
    end

    local chunk = self.chunk
    local consumed = 0
    while consumed < budget and self.row_target_x < chunk.width do
        local r, g, b, a = self.reader.pixel(self.row_source_x, self.row_source_y)
        local absolute_x = chunk.x + self.row_target_x
        if self.row_active_count > 0 then
            a = masked_alpha(
                self.active_masks,
                self.row_active_count,
                absolute_x,
                self.row_step,
                a
            )
        end

        if self.row_run_x
            and (absolute_x ~= self.row_run_end + 1
                or self.row_run_r ~= r
                or self.row_run_g ~= g
                or self.row_run_b ~= b
                or self.row_run_a ~= a) then
            paint(
                self.ops,
                self.canvas,
                self.row_run_x,
                self.row_absolute_y,
                self.row_run_end - self.row_run_x + 1,
                self.row_run_r,
                self.row_run_g,
                self.row_run_b,
                self.row_run_a
            )
            self.row_run_x = nil
        end
        if not self.row_run_x then
            self.row_run_x = absolute_x
            self.row_run_r = r
            self.row_run_g = g
            self.row_run_b = b
            self.row_run_a = a
        end
        self.row_run_end = absolute_x

        if self.row_direct_width then
            self.row_source_x = self.row_source_x + self.row_step
        else
            self.row_source_x = self.row_source_x + self.row_source_step
            self.row_source_error = self.row_source_error + self.row_source_delta
            if self.row_source_error >= chunk.width then
                self.row_source_x = self.row_source_x + 1
                self.row_source_error = self.row_source_error - chunk.width
            end
        end
        self.row_target_x = self.row_target_x + self.row_step
        consumed = consumed + 1
    end

    if self.row_target_x >= chunk.width then
        if self.row_run_x then
            paint(
                self.ops,
                self.canvas,
                self.row_run_x,
                self.row_absolute_y,
                self.row_run_end - self.row_run_x + 1,
                self.row_run_r,
                self.row_run_g,
                self.row_run_b,
                self.row_run_a
            )
        end
        self.row_started = false
        return consumed, true
    end
    return consumed, false
end

local function select_masks(self, chunk)
    local count = 0
    local selected = self.chunk_masks
    for index = 1, #self.masks do
        local mask = self.masks[index]
        if chunk.x < mask.x + mask.width
            and mask.x < chunk.x + chunk.width
            and chunk.y < mask.y + mask.height
            and mask.y < chunk.y + chunk.height then
            count = count + 1
            selected[count] = mask
        end
    end
    for index = count + 1, #selected do
        selected[index] = nil
    end
end

local function finish_chunk(self)
    if self.chunk.command == self.chunk.command:upper() then
        self.ops.commit(self.canvas)
    end
    self.chunk = nil
    self.reader = nil
    self.command = nil
    self.row_started = false
    self.members[self.member_index] = nil
    self.member_index = self.member_index + 1
    if self.input_done and self.member_index > self.member_count then
        self.done = true
    end
end

local function prepare_chunk(self)
    if not self.chunk and self.member_index <= self.member_count then
        local chunk = parse_chunk(self.members[self.member_index], self.width, self.height)
        local reader = make_reader(chunk)
        local command = lower(chunk.command)

        if command == 'e' then
            if chunk.extension ~= 'pcx' then
                error('zcis erase mask must be pcx')
            end
            self.masks[#self.masks + 1] = {
                x = chunk.x,
                y = chunk.y,
                width = chunk.width,
                height = chunk.height,
                reader = reader,
                direct_width = reader.width == chunk.width,
                direct_height = reader.height == chunk.height
            }
            self.chunk = chunk
            finish_chunk(self)
            return true
        else
            if chunk.extension == 'pcx' then
                error('pcx is only valid for zcis erase masks')
            end
            self.chunk = chunk
            self.reader = reader
            self.command = command
            self.target_y = 0
            select_masks(self, chunk)
        end
    end

    if self.input_done and self.member_index > self.member_count then
        self.done = true
    end
    return false
end

local finish_input

local function step(self, pixels)
    if self.parser and not self.parser.closed then
        local parser_done = self.parser:step(2)
        if parser_done and not self.input_done then
            finish_input(self)
        end
    end
    if self.done then return true end
    if not self.canvas then return false end

    local processed = 0
    while processed < (pixels or 1) and not self.done do
        local prepared = prepare_chunk(self)
        if prepared then
            processed = processed + 1
        elseif self.chunk then
            local used, row_done = draw_pixels(self, (pixels or 1) - processed)
            if used == 0 then
                return false
            end
            processed = processed + used
            if row_done then
                self.target_y = self.target_y + 1
                if self.target_y >= self.chunk.height then
                    finish_chunk(self)
                end
            end
        else
            return false
        end
    end
    return self.done
end

local function is_done(self)
    return self.done
end

local function close(self)
    if not self.done then
        error('zcis decoder is not done')
    end
    return self.canvas, self.width, self.height
end

local function add_member(self, member)
    if not self.canvas then
        if member.name ~= '000000000000.txt' then
            error('missing zcis header')
        end
        self.width, self.height = parse_bounds(member)
        self.canvas = self.ops.start(self.width, self.height)
        return
    end
    self.member_count = self.member_count + 1
    self.members[self.member_count] = member
end

finish_input = function(self)
    if not self.canvas then
        error('missing zcis header')
    end
    self.input_done = true
    if not self.chunk and self.member_index > self.member_count then
        self.done = true
    end
end

local function create(ops)
    return {
        members = {},
        member_index = 1,
        member_count = 0,
        width = 0,
        height = 0,
        masks = {},
        chunk_masks = {},
        active_masks = {},
        ops = ops,
        done = false,
        input_done = false,
        step = step,
        is_done = is_done,
        close = close
    }
end

local function stream(ops)
    local decoder = create(ops)
    local parser = ar.new(function(member)
        add_member(decoder, member)
    end)
    decoder.parser = parser
    decoder.push = function(self, data)
        parser:push(data)
    end
    decoder.finish = function(self)
        parser:finish()
    end
    return decoder
end

local function new(body, ops)
    local decoder = create(ops)
    local members = ar.parse(body)
    for index = 1, #members do
        add_member(decoder, members[index])
    end
    finish_input(decoder)
    return decoder
end

local function decode(body, ops)
    local decoder = new(body, ops)
    while not decoder:is_done() do
        decoder:step(64)
    end
    return decoder:close()
end

return {
    stream = stream,
    new = new,
    decode = decode
}
