local test = require('tests/framework/microtest')
local draw_image = require('ee/engine/core/bind/ginga/draw_image_new')

local function member(name, data)
    local stored_name = #name < 16 and name..'/' or name
    local header = string.format('%-16s%-12d%-6d%-6d%-8o%-10d`\n', stored_name, 0, 0, 0, 420, #data)
    return header..data..(#data % 2 == 1 and '\n' or '')
end

function test_remote_zcis_image()
    local ppm = 'P6\n1 1\n255\n'..string.char(12, 34, 56)
    local body = '!<arch>\n'
        ..member('000000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', ppm)
    local texture = {rectangles = 0, commits = 0}

    function texture:attrColor(r, g, b, a)
        self.color = {r, g, b, a}
    end

    function texture:drawRect(_, x, y, width, height)
        self.rectangles = self.rectangles + 1
        self.rectangle = {x, y, width, height}
    end

    function texture:flush()
        self.commits = self.commits + 1
    end

    function texture:attrSize()
        return 1, 1
    end

    local canvas = {}
    function canvas.new(_, width, height)
        assert(width == 1 and height == 1)
        return texture
    end

    function canvas:compose(x, y, image)
        self.composed = {x, y, image}
    end

    local requests = {}
    local loop
    local std = {
        image = {},
        http = {},
        bus = {
            listen = function(name, handler)
                assert(name == 'loop')
                loop = handler
            end
        }
    }
    function std.http.get(url)
        local request = {url = url}
        function request:success(handler)
            self.success_handler = handler
            return self
        end
        function request:failed(handler)
            self.failed_handler = handler
            return self
        end
        function request:error(handler)
            self.error_handler = handler
            return self
        end
        function request:run()
            requests[#requests + 1] = self
        end
        return request
    end

    local engine = {canvas = canvas, offset_x = 3, offset_y = 4}
    draw_image.install(std, engine)
    std.image.unload_all()

    local first_url = 'http://localhost/first.zcis'
    local second_url = 'http://localhost/second.zcis'
    local first_id, first_loading = std.image.load(first_url)
    assert(first_id and first_loading == false)
    loop()
    std.image.unload(first_url)

    local second_id, second_loading = std.image.load(second_url)
    assert(second_id and second_loading == false)
    loop()
    requests[1].success_handler({http = {body = body}})
    assert(not std.image.exists(second_url))

    local second_request = requests[2]
    second_request.stream(body:sub(1, 7))
    second_request.stream(body:sub(8, 70))
    second_request.stream(body:sub(71))
    second_request.success_handler({http = {body = ''}})
    for _ = 1, 4 do
        loop()
    end
    assert(std.image.exists(second_url))
    assert(std.image.error(second_url) == nil)
    assert(texture.rectangles == 1 and texture.commits == 1)

    local error_url = 'http://localhost/error.zcis'
    std.image.load(error_url)
    loop()
    local error_request = requests[3]
    error_request.stream('<html>')
    error_request.failed_handler({http = {status = 404}})
    assert(std.image.error(error_url) == '404')

    local width, height = std.image.mensure(second_url)
    assert(width == 1 and height == 1)
    std.image.draw(second_url, 5, 6)
    assert(canvas.composed[1] == 8 and canvas.composed[2] == 10)
    assert(canvas.composed[3] == texture)
    std.image.unload_all()
end

test.unit(_G)
