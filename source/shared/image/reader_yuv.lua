local math = require('math')
local convert = require('source/shared/image/convert_color')

local floor = math.floor
local ceil = math.ceil
local yuv2rgb = convert.yuv2rgb
local inv_256 = 1 / 256

local chroma_420 = {
    ['420'] = true,
    ['420jpeg'] = true,
    ['420mpeg2'] = true,
    ['420paldv'] = true
}

local function limited_yuv2rgb(y, u, v)
    local c = y - 16
    local r = floor((298 * c + 409 * v + 128) * inv_256)
    local g = floor((298 * c - 100 * u - 208 * v + 128) * inv_256)
    local b = floor((298 * c + 516 * u + 128) * inv_256)
    if r < 0 then r = 0 elseif r > 255 then r = 255 end
    if g < 0 then g = 0 elseif g > 255 then g = 255 end
    if b < 0 then b = 0 elseif b > 255 then b = 255 end
    return r, g, b
end

local function raw(data, offset, size, width, height, limited)
    if width <= 0 or height <= 0 then
        error('invalid yuv dimensions')
    end

    local y_size = width * height
    local uv_width = ceil(width / 2)
    local uv_height = ceil(height / 2)
    local uv_size = uv_width * uv_height
    local frame_size = y_size + uv_size * 2
    if size < frame_size then
        error('truncated yuv frame')
    end

    local u_offset = offset + y_size
    local v_offset = u_offset + uv_size
    local convert_pixel = limited ~= false and limited_yuv2rgb or yuv2rgb

    local cached_y = -1
    local cached_uv = -1
    local y_row = 0
    local uv_row = 0
    local u_value = 0
    local v_value = 0

    local function pixel(x, y)
        if y ~= cached_y then
            cached_y = y
            cached_uv = -1
            y_row = y * width
            uv_row = floor(y / 2) * uv_width
        end
        local uv_index = uv_row + floor(x / 2)
        if uv_index ~= cached_uv then
            cached_uv = uv_index
            u_value = data:byte(u_offset + uv_index) - 128
            v_value = data:byte(v_offset + uv_index) - 128
        end
        local y_value = data:byte(offset + y_row + x)
        local r, g, b = convert_pixel(y_value, u_value, v_value)
        return r, g, b, 255
    end

    return {
        width = width,
        height = height,
        pixel = pixel
    }
end

local function y4m(data, offset, size)
    local limit = offset + size - 1
    local header_end = data:find('\n', offset, true)
    if not header_end or header_end > limit then
        error('invalid y4m header')
    end

    local header = data:sub(offset, header_end - 1)
    if header:sub(1, 9) ~= 'YUV4MPEG2' then
        error('invalid y4m magic')
    end

    local width = tonumber(header:match(' W(%d+)'))
    local height = tonumber(header:match(' H(%d+)'))
    local chroma = header:match(' C(%w+)') or '420'
    local color_range = header:match(' XCOLORRANGE=([A-Z]+)')
    if not width or not height or not chroma_420[chroma] then
        error('unsupported y4m format')
    end
    if color_range and color_range ~= 'FULL' and color_range ~= 'LIMITED' then
        error('unsupported y4m color range')
    end

    local frame_header_end = data:find('\n', header_end + 1, true)
    if not frame_header_end or frame_header_end > limit then
        error('invalid y4m frame header')
    end
    if data:sub(header_end + 1, frame_header_end - 1):sub(1, 5) ~= 'FRAME' then
        error('invalid y4m frame')
    end

    local frame_offset = frame_header_end + 1
    return raw(data, frame_offset, limit - frame_offset + 1, width, height, color_range ~= 'FULL')
end

return {
    raw = raw,
    y4m = y4m
}
