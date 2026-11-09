local math = require('math')

local floor = math.floor
local masks = {128, 64, 32, 16, 8, 4, 2, 1}

--- os oito pixeis de cada byte, prontos, em '\1' opaco e '\0' transparente.
-- a tabela e montada uma vez na carga e depois nao se faz conta nenhuma por pixel:
-- a linha inteira vira uma string de um byte por pixel com uma busca a cada oito.
--
-- o byte e lido de tras para frente de proposito. tirar o bit de baixo e dividir por
-- dois e subtrair o dobro do resultado, que e o mais barato que da para fazer sem
-- operador de bit -- e ginga nao tem operador de bit. ir do outro lado obrigaria a
-- dividir por 128, 64, 32 e por ai, que e uma constante diferente a cada passo.
local spread = {}
for value = 0, 255 do
    local pixels = {}
    local rest = value
    for index = 8, 1, -1 do
        local half = floor(rest / 2)
        pixels[index] = string.char(rest - half - half)
        rest = half
    end
    spread[value] = table.concat(pixels)
end

local function little16(data, offset)
    local low, high = data:byte(offset, offset + 1)
    return low + high * 256
end

local function make_rle_rows(data, offset, limit, bytes_per_line, height)
    local rows = {}
    local pieces = {}
    local row_size = 0
    local run = 0
    local value

    local function finish_row()
        rows[#rows + 1] = table.concat(pieces)
        pieces = {}
        row_size = 0
        if #rows == height and run > 0 then
            error('invalid pcx run')
        end
    end

    local function prepare(y, budget)
        local target = y + 1
        local remaining = budget or bytes_per_line

        while #rows < target and remaining > 0 do
            local row_remaining = bytes_per_line - row_size
            if run > 0 then
                local count = run < row_remaining and run or row_remaining
                if count > remaining then count = remaining end
                pieces[#pieces + 1] = string.rep(string.char(value), count)
                run = run - count
                row_size = row_size + count
                remaining = remaining - count
            else
                if offset > limit then
                    error('truncated pcx data')
                end
                local byte = data:byte(offset)
                if byte >= 192 then
                    offset = offset + 1
                    run = byte - 192
                    if run == 0 or offset > limit then
                        error('invalid pcx run')
                    end
                    value = data:byte(offset)
                    offset = offset + 1
                else
                    local start = offset
                    local count = 0
                    local maximum = row_remaining < remaining and row_remaining or remaining
                    while count < maximum
                        and offset <= limit
                        and data:byte(offset) < 192 do
                        offset = offset + 1
                        count = count + 1
                    end
                    pieces[#pieces + 1] = data:sub(start, start + count - 1)
                    row_size = row_size + count
                    remaining = remaining - count
                end
            end

            if row_size == bytes_per_line then
                finish_row()
            end
        end
        return #rows >= target
    end

    local function get_row(y)
        if not prepare(y, bytes_per_line) then
            error('pcx row is not prepared')
        end
        return rows[y + 1]
    end

    return get_row, prepare
end

local function new(data, offset, size)
    local limit = offset + size - 1
    if size < 128 or data:byte(offset) ~= 10 then
        error('invalid pcx magic')
    end

    local encoding = data:byte(offset + 2)
    local bits = data:byte(offset + 3)
    local x_min = little16(data, offset + 4)
    local y_min = little16(data, offset + 6)
    local x_max = little16(data, offset + 8)
    local y_max = little16(data, offset + 10)
    local planes = data:byte(offset + 65)
    local bytes_per_line = little16(data, offset + 66)
    local width = x_max - x_min + 1
    local height = y_max - y_min + 1

    if bits ~= 1 or planes ~= 1 or width <= 0 or height <= 0 or bytes_per_line * 8 < width then
        error('unsupported pcx format')
    end

    local pixel_offset = offset + 128
    local get_byte
    local get_row
    local prepare
    if encoding == 0 then
        if pixel_offset + bytes_per_line * height - 1 > limit then
            error('truncated pcx data')
        end
        get_row = function(y)
            local at = pixel_offset + y * bytes_per_line
            return data:sub(at, at + bytes_per_line - 1)
        end
        get_byte = function(x, y)
            return data:byte(pixel_offset + y * bytes_per_line + floor(x / 8))
        end
    elseif encoding == 1 then
        get_row, prepare = make_rle_rows(data, pixel_offset, limit, bytes_per_line, height)
        get_byte = function(x, y)
            return get_row(y):byte(floor(x / 8) + 1)
        end
    else
        error('unsupported pcx encoding')
    end

    local function alpha(x, y)
        local byte = get_byte(x, y)
        return floor(byte / masks[x % 8 + 1]) % 2 == 1 and 255 or 0
    end

    --- uma linha inteira como um byte por pixel, '\1' onde se pinta.
    -- quem le a mascara pixel a pixel paga uma divisao e uma chamada de funcao em
    -- cada um; quem le assim paga uma busca de tabela a cada oito e depois so
    -- string.byte, que nao e conta nenhuma.
    local function row(y)
        local packed = get_row(y)
        local out = {}
        for index = 1, #packed do
            out[index] = spread[packed:byte(index)]
        end
        return table.concat(out)
    end

    return {
        width = width,
        height = height,
        alpha = alpha,
        row = row,
        prepare = prepare
    }
end

return {
    new = new
}
