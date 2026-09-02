local test = require('tests/framework/microtest')
local zcis = require('source/shared/image/decoder_zcis')
local pcx = require('source/shared/image/reader_pcx')
local yuv = require('source/shared/image/reader_yuv')

local function raw_member(name, data)
    local header = string.format('%-16s%-12d%-6d%-6d%-8o%-10d`\n', name, 0, 0, 0, 420, #data)
    assert(#header == 60)
    return header..data..(#data % 2 == 1 and '\n' or '')
end

local function member(name, data)
    return raw_member(#name < 16 and name..'/' or name, data)
end

local function archive(bounds, chunks)
    local body = '!<arch>\n'..member('000000000000.txt', bounds)
    for index = 1, #chunks do
        body = body..member(chunks[index][1], chunks[index][2])
    end
    return body
end

local function ppm_data(width, height, pixels)
    return string.format('P6\n%d %d\n255\n', width, height)..pixels
end

local function canvas_ops()
    local canvas
    local ops = {
        start = function(width, height)
            canvas = {width = width, height = height, rectangles = {}, commits = 0}
            return canvas
        end,
        color = function(target, r, g, b, a)
            target.color = {r, g, b, a}
        end,
        pixel = function(target, x, y, width, height)
            target.rectangles[#target.rectangles + 1] = {x, y, width, height, target.color[1], target.color[2], target.color[3], target.color[4]}
        end,
        commit = function(target)
            target.commits = target.commits + 1
        end
    }
    return ops, function() return canvas end
end

local function pcx_mask(height)
    height = height or 1
    local header = {}
    for index = 1, 128 do
        header[index] = 0
    end
    header[1] = 10
    header[3] = 1
    header[4] = 1
    header[9] = 1
    header[11] = (height - 1) % 256
    header[12] = math.floor((height - 1) / 256)
    header[66] = 1
    header[67] = 1
    for index = 1, 128 do
        header[index] = string.char(header[index])
    end
    return table.concat(header)..string.rep(string.char(128), height)
end

function test_zcis_ppm_commit()
    local ops, get_canvas = canvas_ops()
    local body = archive('0 0 2 1\r\n', {
        {'1A00000201.ppm', ppm_data(2, 1, string.char(255, 0, 0, 0, 255, 0))}
    })
    local result, width, height = zcis.decode(body, ops)
    local canvas = get_canvas()
    assert(result == canvas)
    assert(width == 2 and height == 1)
    assert(canvas.commits == 1)
    assert(#canvas.rectangles == 2)
    assert(canvas.rectangles[1][5] == 255 and canvas.rectangles[1][6] == 0)
    assert(canvas.rectangles[2][5] == 0 and canvas.rectangles[2][6] == 255)
end

function test_zcis_pcx_erase_mask()
    local ops, get_canvas = canvas_ops()
    local body = archive('0 0 2 1\r\n', {
        {'1e00000201.pcx', pcx_mask()},
        {'2A00000201.ppm', ppm_data(2, 1, string.char(255, 255, 255, 255, 255, 255))}
    })
    zcis.decode(body, ops)
    local canvas = get_canvas()
    assert(canvas.rectangles[1][8] == 255)
    assert(canvas.rectangles[2][8] == 0)
end

function test_zcis_patterns()
    local white = ppm_data(2, 2, string.rep(string.char(255), 12))
    local ops, get_canvas = canvas_ops()
    zcis.decode(archive('0 0 8 2\r\n', {
        {'1A00000202.ppm', white},
        {'2B02000202.ppm', white},
        {'3C04000202.ppm', white},
        {'4D06000202.ppm', white}
    }), ops)
    local rectangles = get_canvas().rectangles
    assert(#rectangles == 6)
    assert(rectangles[1][1] == 0 and rectangles[1][3] == 2)
    assert(rectangles[3][1] == 2 and rectangles[4][1] == 2)
    assert(rectangles[5][1] == 4 and rectangles[5][3] == 2)
    assert(rectangles[6][1] == 6)
end

function test_yuv420_reader()
    local data = string.char(16, 235, 81, 145, 128, 128)
    local reader = yuv.raw(data, 1, #data, 2, 2)
    local r1, g1, b1 = reader.pixel(0, 0)
    local r2, g2, b2 = reader.pixel(1, 0)
    assert(r1 == 0 and g1 == 0 and b1 == 0)
    assert(r2 == 255 and g2 == 255 and b2 == 255)
    local full_reader = yuv.raw(data, 1, #data, 2, 2, false)
    local full_r1 = full_reader.pixel(0, 0)
    local full_r2 = full_reader.pixel(1, 0)
    assert(full_r1 == 16 and full_r2 == 235)
end

function test_pcx_reader()
    local data = pcx_mask()
    local reader = pcx.new(data, 1, #data)
    assert(reader.width == 2 and reader.height == 1)
    assert(reader.alpha(0, 0) == 255)
    assert(reader.alpha(1, 0) == 0)
end

function test_pcx_reader_prepares_bounded_rows()
    local data = pcx_mask(20)
    local reader = pcx.new(data, 1, #data)
    assert(not reader.prepare(19, 8))
    assert(not reader.prepare(19, 8))
    assert(reader.prepare(19, 8))
    assert(reader.alpha(0, 19) == 255)
end

function test_zcis_gnu_string_table()
    local bounds = '0 0 1 1\r\n'
    local ppm = ppm_data(1, 1, string.char(1, 2, 3))
    local body = '!<arch>\n'
        ..raw_member('//', '000000000000.txt/\n')
        ..raw_member('/0', bounds)
        ..member('1A00000101.ppm', ppm)
    local ops, get_canvas = canvas_ops()
    zcis.decode(body, ops)
    assert(get_canvas().rectangles[1][5] == 1)
end

function test_zcis_skips_bsd_symbol_table()
    local bounds = '0 0 1 1\r\n'
    local ppm = ppm_data(1, 1, string.char(4, 5, 6))
    local body = '!<arch>\n'
        ..raw_member('#1/9', '__.SYMDEF'..'index')
        ..member('000000000000.txt', bounds)
        ..member('1A00000101.ppm', ppm)
    local ops, get_canvas = canvas_ops()
    zcis.decode(body, ops)
    assert(get_canvas().rectangles[1][5] == 4)
end

function test_zcis_accepts_bsd_padded_name()
    local bounds = '0 0 1 1\r\n'
    local ppm = ppm_data(1, 1, string.char(7, 8, 9))
    local body = '!<arch>\n'
        ..raw_member('#1/20', '000000000000.txt\0\0\0\0'..bounds)
        ..member('1A00000101.ppm', ppm)
    local ops, get_canvas = canvas_ops()
    zcis.decode(body, ops)
    assert(get_canvas().rectangles[1][5] == 7)
end

function test_zcis_rejects_oversized_bounds()
    local started = false
    local ok = pcall(zcis.new, archive('0 0 3844 1\r\n', {}), {
        start = function()
            started = true
        end
    })
    assert(not ok and not started)
end

function test_zcis_incremental_rows()
    local white = ppm_data(1, 2, string.rep(string.char(255), 6))
    local ops = canvas_ops()
    local decoder = zcis.new(archive('0 0 1 2\r\n', {
        {'1A00000102.ppm', white}
    }), ops)
    assert(not decoder:step(1))
    assert(decoder:step(1))
end

function test_zcis_stream_rejects_missing_header()
    local ops = canvas_ops()
    local decoder = zcis.stream(ops)
    decoder:push('!<arch>\n')
    decoder:finish()
    assert(not pcall(decoder.step, decoder, 1))
end

function test_y4m_limited_range()
    local frame = string.char(16, 235, 81, 145, 128, 128)
    local data = 'YUV4MPEG2 W2 H2 F1:1 Ip A1:1 C420\nFRAME\n'..frame
    local reader = yuv.y4m(data, 1, #data)
    local r1, g1, b1 = reader.pixel(0, 0)
    local r2, g2, b2 = reader.pixel(1, 0)
    assert(r1 == 0 and g1 == 0 and b1 == 0)
    assert(r2 == 255 and g2 == 255 and b2 == 255)
    local full_data = 'YUV4MPEG2 W2 H2 C420 XCOLORRANGE=FULL\nFRAME\n'..frame
    local full_reader = yuv.y4m(full_data, 1, #full_data)
    local full_r1 = full_reader.pixel(0, 0)
    local full_r2 = full_reader.pixel(1, 0)
    assert(full_r1 == 16 and full_r2 == 235)
end

function test_y4m_rejects_high_bit_depth()
    local data = 'YUV4MPEG2 W2 H2 C420p10\nFRAME\n'..string.rep('\0', 12)
    assert(not pcall(yuv.y4m, data, 1, #data))
end

test.unit(_G)
