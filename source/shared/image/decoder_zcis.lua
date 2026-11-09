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
    local cuts = {}

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
        cuts[#cuts + 1] = {x = x, y = y, width = w, height = h}
    end

    if #cuts == 0 then
        error('empty zcis header')
    end

    return width, height, cuts
end

--- os retangulos que o corpo de um preenchimento lista, um por linha em decimal
local function parse_rects(member, atlas_width, atlas_height)
    local body = member.body:sub(member.offset, member.offset + member.size - 1)
    local rects = {}

    for line in body:gmatch('[^\r\n]+') do
        local x, y, width, height = line:match('^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)$')
        x = tonumber(x)
        y = tonumber(y)
        width = tonumber(width)
        height = tonumber(height)
        if not x or not height or width <= 0 or height <= 0
            or x + width > atlas_width or y + height > atlas_height then
            error('invalid zcis fill rectangle')
        end
        rects[#rects + 1] = {x = x, y = y, width = width, height = height}
    end

    if #rects == 0 then
        error('empty zcis fill')
    end
    return rects
end

--- a cor que o nome de um preenchimento carrega, dois digitos por canal
local function parse_colour(hex)
    return {
        r = tonumber(hex:sub(1, 2), 16),
        g = tonumber(hex:sub(3, 4), 16),
        b = tonumber(hex:sub(5, 6), 16),
        a = tonumber(hex:sub(7, 8), 16)
    }
end

--- o preenchimento, cujo nome e a cor e cujo corpo sao os retangulos dela.
--
-- a cor vem no nome e nao no corpo porque um membro por cor junta todos os
-- retangulos dela, e o nome ja estava ali de graca. os oito digitos caem onde um
-- chunk de imagem poe as quatro posicoes, entao e a letra do comando que decide como
-- o nome e lido -- por isso isto e tentado antes.
local function parse_fill(member, atlas_width, atlas_height)
    local command, hex, extension = member.name:match('^[0-9A-Za-z]([fF])(%x%x%x%x%x%x%x%x)%.(%a+)$')
    if not command then
        return nil
    end
    if lower(extension) ~= 'txt' then
        error('zcis fill must be txt')
    end
    return {
        command = command,
        fill = parse_colour(hex),
        rects = parse_rects(member, atlas_width, atlas_height),
        extension = 'txt',
        member = member
    }
end

local function parse_chunk(member, atlas_width, atlas_height)
    local filled = parse_fill(member, atlas_width, atlas_height)
    if filled then
        return filled
    end

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
    if chunk.fill then
        return chunk.fill
    end
    if member.stream then
        local data = member.stream:read(math.min(member.size, 1024))
        return data and ppm.new(data, 1, member.size, member.stream)
    elseif chunk.extension == 'ppm' then
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

--- as faixas da linha que ainda se desenha, em coordenadas do chunk e base 1.
--
-- a mascara existe sempre e comeca inteira preenchida: o comando e nao traz uma
-- mascara nova, apaga um pedaco da que ja estava la. por isso o nil aqui quer dizer
-- "nada foi apagado nessa linha", que e o caso de quase toda linha de quase todo
-- arquivo, e nesse caso nao se gasta nada.
--
-- a linha da mascara chega como um byte por pixel e as faixas saem dela com
-- string.find, que roda em c. achar as faixas assim e varias vezes mais barato do
-- que perguntar pixel a pixel se ele esta apagado -- e o que importa e que depois
-- disso o trecho apagado e pulado de uma vez, sem nem ler o pixel que estava la.
local function drawn_spans(bits, from, to)
    local spans = {}
    local count = 0
    local at = from
    while at <= to do
        local first, last = bits:find('\1+', at)
        if not first or first > to then break end
        if last > to then last = to end
        spans[count + 1] = first
        spans[count + 2] = last
        count = count + 2
        at = last + 1
    end
    return spans, count
end

--- o que sobra de duas listas de faixas, que e a interseccao delas
local function both(left, left_count, right, right_count)
    local out = {}
    local count = 0
    local a = 1
    local b = 1
    while a <= left_count and b <= right_count do
        local from = left[a] > right[b] and left[a] or right[b]
        local to = left[a + 1] < right[b + 1] and left[a + 1] or right[b + 1]
        if from <= to then
            out[count + 1] = from
            out[count + 2] = to
            count = count + 2
        end
        if left[a + 1] < right[b + 1] then a = a + 2 else b = b + 2 end
    end
    return out, count
end

--- a mascara de uma linha, ja recortada ao chunk, ou nil quando nada foi apagado
local function row_mask(self, chunk, y)
    local masks = self.chunk_masks
    local spans, count = nil, 0

    for index = 1, #masks do
        local mask = masks[index]
        local inside = y - mask.y
        if inside >= 0 and inside < mask.height then
            local source_y = mask.direct_height and inside
                or floor(inside * mask.reader.height / mask.height)
            if mask.reader.prepare and not mask.reader.prepare(source_y, 2048) then
                return nil, nil
            end

            local bits = mask.reader.row(source_y)
            local mine, how_many
            if mask.direct_width and mask.x == chunk.x and mask.width >= chunk.width then
                -- o caso que o encoder escreve: mesma largura, mesmo lugar
                mine, how_many = drawn_spans(bits, 1, chunk.width)
            else
                local wide = {}
                for at = 1, chunk.width do
                    local x = chunk.x + at - 1 - mask.x
                    if x < 0 or x >= mask.width then
                        wide[at] = '\1'
                    else
                        local source_x = mask.direct_width and x
                            or floor(x * mask.reader.width / mask.width)
                        wide[at] = string.char(bits:byte(source_x + 1))
                    end
                end
                mine, how_many = drawn_spans(table.concat(wide), 1, chunk.width)
            end

            if not spans then
                spans, count = mine, how_many
            else
                spans, count = both(spans, count, mine, how_many)
            end
        end
    end
    return spans, count
end

--- pinta um retangulo de uma cor so, que e o unico desenho que existe aqui.
--
-- alpha zero nao e pintado. a televisao cobra a chamada de cor e a de retangulo do
-- mesmo jeito tenha o que pintar ou nao, entao desenhar o que a mascara ja apagou
-- custaria exatamente o que a mascara existe para poupar.
local function paint(self, canvas, x, y, width, height, r, g, b, a)
    if a == 0 then return end
    self.ops.color(canvas, r, g, b, a)
    self.ops.pixel(canvas, x, y, width, height)
end

--- onde a fonte esta quando o alvo esta em target_x, recomecado do zero.
--
-- so e preciso quando se salta um trecho apagado, e e por isso que a conta e feita
-- de novo em vez de ir somando: somar so serve para andar de um em um, e a graca de
-- ter a mascara em faixas e justamente nao andar.
local function seek(self, target_x)
    local chunk = self.chunk
    self.row_target_x = target_x
    if self.row_direct_width then
        self.row_source_x = target_x
        self.row_source_error = 0
        return
    end
    local scaled = target_x * self.reader.width
    self.row_source_x = floor(scaled / chunk.width)
    self.row_source_error = scaled - self.row_source_x * chunk.width
end

--- a primeira faixa que ainda alcanca o alvo, ou nil quando a linha acabou
local function next_span(self)
    local spans = self.row_spans
    if not spans then
        if self.row_target_x >= self.chunk.width then return nil end
        return self.chunk.width
    end

    local at = self.row_span
    while at <= self.row_span_count do
        local from = spans[at] - 1
        local to = spans[at + 1]
        if self.row_target_x < to then
            if self.row_target_x < from then
                -- o passo de b e d so pinta coluna par, entao a faixa comeca na
                -- primeira que ele alcanca
                local start = from
                if self.row_step == 2 and start % 2 == 1 then start = start + 1 end
                if start < to then
                    self.row_span = at
                    seek(self, start)
                    return to
                end
            else
                self.row_span = at
                return to
            end
        end
        at = at + 2
    end
    self.row_span = at
    return nil
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

    self.row_step = step
    self.row_direct_width = reader.width == chunk.width
    self.row_source_y = direct_height
        and self.target_y
        or floor(self.target_y * reader.height / chunk.height)
    self.row_absolute_y = absolute_y

    local spans, count = row_mask(self, chunk, absolute_y)
    if #self.chunk_masks > 0 and not spans and not count then
        return nil
    end
    self.row_spans = spans
    self.row_span_count = count or 0
    self.row_span = 1

    local delta = reader.width * step
    self.row_source_step = floor(delta / chunk.width)
    self.row_source_delta = delta - self.row_source_step * chunk.width
    self.row_run_x = nil
    seek(self, 0)
    self.row_started = true
    return false
end

local function flush_run(self)
    if not self.row_run_x then return end
    paint(
        self,
        self.canvas,
        self.row_run_x,
        self.row_absolute_y,
        self.row_run_end - self.row_run_x + 1,
        1,
        self.row_run_r,
        self.row_run_g,
        self.row_run_b,
        self.row_run_a
    )
    self.row_run_x = nil
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

--- pinta os retangulos de um preenchimento, respeitando o que a mascara apagou.
--
-- um retangulo que a mascara nao alcanca sai numa chamada so, com a altura inteira,
-- porque a televisao cobra o mesmo por um retangulo de uma linha e por um de cem.
-- esse e o motivo de o preenchimento existir: e o desenho mais barato que ha.
--
-- so quando alguma mascara encosta nele e que ele vira linha por linha, e ai cada
-- faixa que sobrou sai como um retangulo de uma linha.
local function paint_fill(self, chunk)
    local colour = chunk.fill
    local rects = chunk.rects
    local painted = 0

    for index = 1, #rects do
        local rect = rects[index]
        select_masks(self, rect)

        if #self.chunk_masks == 0 then
            paint(self, self.canvas, rect.x, rect.y, rect.width, rect.height,
                  colour.r, colour.g, colour.b, colour.a)
            painted = painted + 1
        else
            for y = rect.y, rect.y + rect.height - 1 do
                local spans, count = row_mask(self, rect, y)
                if not spans then
                    paint(self, self.canvas, rect.x, y, rect.width, 1,
                          colour.r, colour.g, colour.b, colour.a)
                    painted = painted + 1
                else
                    for at = 1, count, 2 do
                        paint(self, self.canvas, rect.x + spans[at] - 1, y,
                              spans[at + 1] - spans[at] + 1, 1,
                              colour.r, colour.g, colour.b, colour.a)
                        painted = painted + 1
                    end
                end
            end
        end
    end
    return painted
end

local function draw_pixels(self, budget)
    if not self.row_started then
        local skipped = begin_row(self)
        if skipped == nil then return 0, false end
        if skipped then return 1, true end
    end
    if self.reader.prepare and not self.reader.prepare(self.row_source_y) then return 0, false end

    local chunk = self.chunk
    local consumed = 0
    local stop = next_span(self)

    while consumed < budget and stop do
        local r, g, b, a = self.reader.pixel(self.row_source_x, self.row_source_y)
        local absolute_x = chunk.x + self.row_target_x

        if self.row_run_x
            and (absolute_x ~= self.row_run_end + 1
                or self.row_run_r ~= r
                or self.row_run_g ~= g
                or self.row_run_b ~= b
                or self.row_run_a ~= a) then
            flush_run(self)
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

        if self.row_target_x >= stop then
            -- a faixa acabou: o que vem depois nao encosta nela, entao a run fecha
            flush_run(self)
            self.row_span = self.row_span + 2
            stop = next_span(self)
        end
    end

    if not stop then
        flush_run(self)
        self.row_started = false
        -- uma linha que a mascara apagou inteira nao desenha nada, e e justamente
        -- por isso que ela existe; mas quem chama le zero como "ainda nao deu, volte
        -- depois", entao ela conta como um passo mesmo sem ter pintado
        if consumed == 0 then
            return 1, true
        end
        return consumed, true
    end
    return consumed, false
end

local function touch_rect(self, rect)
    for index = 1, #self.cuts do
        local cut = self.cuts[index]
        if rect.x < cut.x + cut.width and cut.x < rect.x + rect.width
            and rect.y < cut.y + cut.height and cut.y < rect.y + rect.height then
            self.touched[index] = true
        end
    end
end

--- quais cortes o chunk encostou, que e o que decide o que um commit mostra.
-- um preenchimento nao tem um retangulo so, tem a lista que o corpo dele trouxe.
local function touch_cuts(self, chunk)
    if chunk.rects then
        for index = 1, #chunk.rects do
            touch_rect(self, chunk.rects[index])
        end
        return
    end
    touch_rect(self, chunk)
end

local function finish_chunk(self)
    touch_cuts(self, self.chunk)
    if self.chunk.command == self.chunk.command:upper() then
        for index = 1, #self.cuts do
            if self.touched[index] then
                self.ready[#self.ready + 1] = index
                self.touched[index] = nil
            end
        end
        self.ops.commit(self.canvas)
        self.commits = self.commits + 1
    end
    if self.chunk.member.stream then self.chunk.member.stream:read() end
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
        if not reader then return false end
        local command = lower(chunk.command)

        if command == 'f' then
            paint_fill(self, chunk)
            self.chunk = chunk
            finish_chunk(self)
            return true
        end

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

local function step(self, pixels, until_commit)
    local commits = self.commits
    if self.parser and not self.parser.closed then
        local parser_done = self.parser:step(2)
        if parser_done and not self.input_done then
            finish_input(self)
        end
    end
    if self.done then return true end
    if not self.canvas then return false, true end

    local processed = 0
    while processed < (pixels or 1) and not self.done do
        local prepared = prepare_chunk(self)
        if prepared then
            processed = processed + 1
        elseif self.chunk then
            local used, row_done = draw_pixels(self, (pixels or 1) - processed)
            if used == 0 then
                return false, true
            end
            processed = processed + used
            if row_done then
                self.target_y = self.target_y + 1
                if self.target_y >= self.chunk.height then
                    finish_chunk(self)
                    if until_commit and self.commits ~= commits then
                        return self.done
                    end
                end
            end
        else
            return false, true
        end
    end
    return self.done
end

local function step_commit(self)
    local commits = self.commits
    while true do
        local done, waiting = step(self, 2048, true)
        if done or waiting or self.commits ~= commits then
            return done, waiting
        end
    end
end

local function take_ready(self)
    local ready = self.ready
    self.ready = {}
    return ready
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
        if not member.name:match('^0+%.txt$') then
            error('missing zcis header')
        end
        self.width, self.height, self.cuts = parse_bounds(member)
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
        cuts = {},
        touched = {},
        ready = {},
        masks = {},
        chunk_masks = {},
        active_masks = {},
        ops = ops,
        done = false,
        input_done = false,
        commits = 0,
        step = step,
        step_commit = step_commit,
        take_ready = take_ready,
        is_done = is_done,
        close = close
    }
end

local function stream(ops)
    local decoder = create(ops)
    local parser = ar.new(function(member)
        add_member(decoder, member)
    end, '^%w[aAcC]%w+%.[pP][pP][mM]/?$')
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
