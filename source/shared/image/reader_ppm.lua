local function is_space(byte)
    return byte == 9 or byte == 10 or byte == 13 or byte == 32
end

local function next_token(data, offset, limit)
    while offset <= limit do
        local byte = data:byte(offset)
        if is_space(byte) then
            offset = offset + 1
        elseif byte == 35 then
            local newline = data:find('\n', offset, true)
            if not newline or newline > limit then
                error('invalid ppm comment')
            end
            offset = newline + 1
        else
            break
        end
    end

    local start = offset
    while offset <= limit do
        local byte = data:byte(offset)
        if is_space(byte) or byte == 35 then
            break
        end
        offset = offset + 1
    end

    if start == offset then
        error('invalid ppm header')
    end
    return data:sub(start, offset - 1), offset
end

local function new(data, offset, size)
    local limit = offset + size - 1
    local magic
    magic, offset = next_token(data, offset, limit)
    if magic ~= 'P6' then
        error('invalid ppm magic')
    end

    local width
    local height
    local maxval
    width, offset = next_token(data, offset, limit)
    height, offset = next_token(data, offset, limit)
    maxval, offset = next_token(data, offset, limit)
    width = tonumber(width)
    height = tonumber(height)
    maxval = tonumber(maxval)

    if not width or not height or width <= 0 or height <= 0 or not maxval or maxval <= 0 or maxval > 255 then
        error('invalid ppm dimensions')
    end

    local separator = data:byte(offset)
    if not separator or not is_space(separator) then
        error('invalid ppm separator')
    end
    offset = offset + 1
    if separator == 13 and data:byte(offset) == 10 then
        offset = offset + 1
    end

    local required = width * height * 3
    if offset + required - 1 > limit then
        error('truncated ppm pixels')
    end

    local pixel
    if maxval == 255 then
        pixel = function(x, y)
            local index = offset + (y * width + x) * 3
            local r, g, b = data:byte(index, index + 2)
            return r, g, b, 255
        end
    else
        local scale = 255 / maxval
        pixel = function(x, y)
            local index = offset + (y * width + x) * 3
            local r, g, b = data:byte(index, index + 2)
            return r * scale, g * scale, b * scale, 255
        end
    end

    return {
        width = width,
        height = height,
        pixel = pixel
    }
end

return {
    new = new
}
