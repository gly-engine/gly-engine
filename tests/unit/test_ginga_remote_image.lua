local test = require('tests/framework/microtest')
local draw_image = require('ee/engine/core/bind/ginga/draw_image')

local function member(name, data)
    local header = string.format('%-16s%-12d%-6d%-6d%-8o%-10d`\n', name, 0, 0, 0, 420, #data)
    return header..data..(#data % 2 == 1 and '\n' or '')
end

function test_remote_zcis_image()
    local ppm = 'P6\n1 1\n255\n'..string.char(12, 34, 56)
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', ppm)
    local texture = {points = 0, commits = 0}

    function texture:attrColor(r, g, b, a)
        self.color = {r, g, b, a}
    end

    function texture:drawRect(_, x, y, width)
        local color = self.color or {}
        self.points = self.points + width
        self.point = {x, y, color[1], color[2], color[3], color[4]}
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
    second_request.success_handler({http = {body = body}})
    for _ = 1, 4 do
        loop()
    end
    assert(std.image.exists(second_url))
    assert(std.image.error(second_url) == nil)
    assert(texture.points == 1 and texture.commits == 1)
    assert(table.concat(texture.point, ',') == '0,0,12,34,56,255')

    local error_url = 'http://localhost/error.zcis'
    std.image.load(error_url)
    loop()
    local error_request = requests[3]
    error_request.failed_handler({http = {status = 404}})
    assert(std.image.error(error_url) == '404')

    local width, height = std.image.mensure(second_url)
    assert(width == 1 and height == 1)
    std.image.draw(second_url, 5, 6)
    assert(canvas.composed[1] == 8 and canvas.composed[2] == 10)
    assert(canvas.composed[3] == texture)
    std.image.unload_all()
end

local function fake_engine()
    local texture = {points = 0}
    function texture:attrColor(r, g, b, a)
        self.color = {r, g, b, a}
    end
    function texture:drawRect(_, x, y, width)
        local color = self.color or {}
        self.points = self.points + width
        self.point = {x, y, color[1], color[2], color[3], color[4]}
    end
    function texture:flush() end
    function texture:attrSize()
        return 1, 1
    end

    local canvas = {}
    function canvas.new()
        return texture
    end

    function canvas:compose(x, y, image)
        self.composed = {x, y, image}
    end

    local requests = {}
    local env = {texture = texture, canvas = canvas, requests = requests}
    local std = {
        image = {},
        http = {},
        bus = {
            listen = function(_, handler)
                env.loop = handler
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

    draw_image.install(std, {canvas = canvas, offset_x = 0, offset_y = 0})
    std.image.unload_all()
    env.std = std
    return env
end

function test_remote_zcis_image_cobs()
    local cobs = require('source/shared/string/encode/cobs')
    local ppm = 'P6\n1 1\n255\n'..string.char(0, 34, 0)
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', ppm)
    local stuffed = cobs.encode(body)
    local cobs_headers = {['X-Encoding'] = 'cobs'}

    local env = fake_engine()
    local std = env.std

    std.image.load('http://localhost/a.png')
    std.image.load('http://localhost/b.zcis?format=zcis')
    std.image.load('http://localhost/c?format=zcis&encoding=base64')
    for _ = 1, 3 do
        env.loop()
        local request = env.requests[#env.requests]
        request.success_handler({http = {body = ''}})
    end
    assert(env.requests[1].url == 'http://localhost/a.png')
    assert(env.requests[2].url == 'http://localhost/b.zcis?format=zcis')
    assert(env.requests[3].url == 'http://localhost/c?format=zcis&encoding=base64')
    std.image.unload_all()

    local whole_url = 'http://localhost/whole?format=zcis'
    std.image.load(whole_url)
    env.loop()
    local request = env.requests[#env.requests]
    request.success_handler({http = {body = stuffed, headers = {['x-encoding'] = 'cobs'}}})
    for _ = 1, 4 do
        env.loop()
    end
    assert(std.image.error(whole_url) == nil)
    assert(std.image.exists(whole_url))
    assert(table.concat(env.texture.point, ',') == '0,0,0,34,0,255')
    std.image.unload_all()

    env.texture.point = nil
    local plain_url = 'http://localhost/plain?format=zcis'
    std.image.load(plain_url)
    env.loop()
    request = env.requests[#env.requests]
    request.success_handler({http = {body = body, headers = {}}})
    for _ = 1, 4 do
        env.loop()
    end
    assert(std.image.error(plain_url) == nil)
    assert(table.concat(env.texture.point, ',') == '0,0,0,34,0,255')
    std.image.unload_all()
end

function test_image_handle_id()
    local ppm = 'P6\n1 1\n255\n'..string.char(12, 34, 56)
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', ppm)

    local env = fake_engine()
    local std = env.std
    local url = 'http://localhost/handle.zcis'

    local id, loaded = std.image.load(url)
    assert(id and loaded == false)
    env.loop()
    env.requests[#env.requests].success_handler({http = {body = body}})
    for _ = 1, 4 do
        env.loop()
    end

    assert(std.image.exists(id))
    assert(std.image.error(id) == nil)
    assert(select(1, std.image.load(id)) == id)

    local width, height = std.image.mensure(id)
    assert(width == 1 and height == 1)

    std.image.draw(id, 5, 6)
    assert(env.canvas.composed[1] == 5 and env.canvas.composed[2] == 6)
    assert(env.canvas.composed[3] == env.texture)

    std.image.unload(id)
    assert(not std.image.exists(id))
    assert(select(2, std.image.load(url)) == false)
    std.image.unload_all()

    local broken_id = std.image.load('missing_file.png')
    assert(broken_id)
    assert(std.image.error(broken_id) == 'file not found')
    assert(std.image.error('missing_file.png') == 'file not found')
    std.image.unload_all()
end

function test_remote_image_rejects_non_zcis()
    local env = fake_engine()
    local std = env.std

    local png_url = 'http://localhost/photo.png'
    std.image.load(png_url)
    env.loop()
    env.requests[#env.requests].success_handler({
        http = {body = 'fake png', headers = {['Content-Type'] = 'image/png'}}
    })
    assert(std.image.error(png_url) == 'remote png not supported, use format=zcis')

    local html_url = 'http://localhost/oops'
    std.image.load(html_url)
    env.loop()
    env.requests[#env.requests].success_handler({
        http = {body = '<html>', headers = {['Content-Type'] = 'text/html; charset=utf-8'}}
    })
    assert(std.image.error(html_url) == 'remote image must be zcis')
    std.image.unload_all()
end

function test_remote_fragments_share_one_request()
    local env = fake_engine()
    local std = env.std
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', 'P6\n1 1\n255\n'..string.char(12, 34, 56))
    local url = 'http://localhost/sheet.zcis?format=zcis'

    local first, ready = std.image.load(url, 2)
    assert(first and ready == false)
    assert(std.image.load(url) == first)

    env.loop()
    assert(#env.requests == 1)
    assert(env.requests[1].url == url)

    env.requests[1].success_handler({http = {body = body}})
    for _ = 1, 4 do
        env.loop()
    end

    assert(#env.requests == 1)
    assert(std.image.exists(first))
    std.image.unload_all()
end

function test_remote_image_keeps_the_fragment()
    local env = fake_engine()
    local std = env.std
    local url = 'http://localhost/a.zcis#page=2'

    local id = std.image.load(url)
    assert(id)
    assert(std.image.error(id) == nil)

    env.loop()
    assert(#env.requests == 1)
    assert(env.requests[1].url == url)
    std.image.unload_all()
end

local function sheet_engine()
    local created = {}
    local canvas = {}

    function canvas.new(_, width, height)
        local target = {width = width, height = height, composes = {}}
        function target:pixel() end
        function target:flush() end
        function target:attrColor() end
        function target:drawRect() end
        function target:attrSize()
            return self.width, self.height
        end
        function target:compose(x, y, src)
            self.composes[#self.composes + 1] = {x, y, src}
        end
        created[#created + 1] = target
        return target
    end

    function canvas:compose(x, y, image)
        self.composed = {x, y, image}
    end

    local requests = {}
    local env = {canvas = canvas, created = created, requests = requests}
    local std = {
        image = {},
        http = {},
        bus = {
            listen = function(_, handler)
                env.loop = handler
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

    draw_image.install(std, {canvas = canvas, offset_x = 0, offset_y = 0})
    std.image.unload_all()
    env.std = std
    return env
end

function test_remote_zcis_sheet_carves_each_cut()
    local cobs = require('source/shared/string/encode/cobs')
    local pixels = string.char(0, 34, 0, 56, 0, 78)
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 2 1\r\n4 0 2 1\r\n')
        ..member('1a00000201.ppm', 'P6\n2 1\n255\n'..pixels)
        ..member('2A04000201.ppm', 'P6\n2 1\n255\n'..pixels)

    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/sheet?format=zcis'

    local first = std.image.load(url, 2)
    env.loop()
    env.requests[1].success_handler({http = {body = cobs.encode(body), headers = {['x-encoding'] = 'cobs'}}})
    for _ = 1, 6 do
        env.loop()
    end

    assert(#env.created == 3)
    assert(env.created[1].width == 6 and env.created[1].height == 1)
    assert(env.created[2].width == 2 and env.created[2].height == 1)
    assert(env.created[3].width == 2 and env.created[3].height == 1)

    assert(env.created[2].composes[1][1] == 0 and env.created[2].composes[1][2] == 0)
    assert(env.created[3].composes[1][1] == -4 and env.created[3].composes[1][2] == 0)
    assert(env.created[2].composes[1][3] == env.created[1])
    assert(env.created[3].composes[1][3] == env.created[1])

    assert(std.image.exists(first))
    assert(std.image.exists(first + 1))

    local width, height = std.image.mensure(first + 1)
    assert(width == 2 and height == 1)

    std.image.draw(first + 1, 7, 8)
    assert(env.canvas.composed[3] == env.created[3])
    std.image.unload_all()
end

function test_remote_zcis_whole_image_is_not_copied()
    local env = sheet_engine()
    local std = env.std
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', 'P6\n1 1\n255\n'..string.char(12, 34, 56))

    std.image.load('http://localhost/whole.zcis')
    env.loop()
    env.requests[1].success_handler({http = {body = body}})
    for _ = 1, 6 do
        env.loop()
    end

    assert(#env.created == 1)
    assert(#env.created[1].composes == 0)
    assert(std.image.exists('http://localhost/whole.zcis'))
    std.image.unload_all()
end

function test_remote_image_refuses_https()
    local env = fake_engine()
    local std = env.std

    local id = std.image.load('https://localhost/a.zcis')
    assert(id)
    assert(std.image.error(id) == 'HTTPS is not supported!')

    env.loop()
    assert(#env.requests == 0)
    std.image.unload_all()
end

function test_remote_zcis_refuses_index_out_of_range()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/one.zcis'
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', 'P6\n1 1\n255\n'..string.char(12, 34, 56))

    local first = std.image.load(url, 2)
    env.loop()
    env.requests[1].success_handler({http = {body = body}})
    for _ = 1, 6 do
        env.loop()
    end

    assert(std.image.exists(first))
    assert(not std.image.exists(first + 1))
    assert(std.image.error(first + 1) == 'zcis has 1 cuts, no index 1')
    assert(std.image.error('id://'..(first + 1)) == 'zcis has 1 cuts, no index 1')
    assert(#env.requests == 1)
    std.image.unload_all()
end

function test_remote_zcis_failure_reaches_late_load()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/gone.zcis'

    local first, loaded = std.image.load(url, 2)
    assert(first and loaded == false)
    env.loop()
    env.requests[1].failed_handler({http = {status = 404}})

    assert(std.image.error(first) == '404')
    assert(std.image.error(first + 1) == '404')
    assert(select(2, std.image.load(url, 2)) == false)

    env.loop()
    assert(#env.requests == 1)
    std.image.unload_all()
end

function test_remote_zcis_reload_after_unload_fetches_again()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/again.zcis'
    local body = '!<arch>\n'
        ..member('0000000000.txt', '0 0 1 1\r\n')
        ..member('1A00000101.ppm', 'P6\n1 1\n255\n'..string.char(12, 34, 56))

    std.image.load(url)
    env.loop()
    env.requests[1].success_handler({http = {body = body}})
    for _ = 1, 6 do
        env.loop()
    end
    assert(std.image.exists(url))

    std.image.unload(url)
    assert(not std.image.exists(url))

    std.image.load(url)
    env.loop()
    assert(#env.requests == 2)
    std.image.unload_all()
end

local function sheet_body()
    local pixels = string.char(0, 34, 0, 56, 0, 78)
    return '!<arch>\n'
        ..member('0000000000.txt', '0 0 2 1\r\n2 0 2 1\r\n4 0 2 1\r\n')
        ..member('1A00000201.ppm', 'P6\n2 1\n255\n'..pixels)
        ..member('2A02000201.ppm', 'P6\n2 1\n255\n'..pixels)
        ..member('3A04000201.ppm', 'P6\n2 1\n255\n'..pixels)
end

function test_remote_zcis_sheet_reserves_sequential_ids()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/block.zcis?format=zcis'

    local first, loaded = std.image.load(url, 3)
    assert(first and loaded == false)
    assert(std.image.load(url, 3) == first)
    assert(std.image.load(url) == first)

    env.loop()
    assert(#env.requests == 1)
    env.requests[1].success_handler({http = {body = sheet_body()}})
    for _ = 1, 8 do
        env.loop()
    end

    assert(#env.requests == 1)
    assert(std.image.exists(first))
    assert(std.image.exists(first + 1))
    assert(std.image.exists(first + 2))
    assert(select(2, std.image.load(url, 3)) == true)

    local width, height = std.image.mensure(first + 2)
    assert(width == 2 and height == 1)

    std.image.draw(first + 2, 7, 8)
    assert(env.canvas.composed[1] == 7 and env.canvas.composed[2] == 8)
    assert(env.canvas.composed[3] ~= nil)

    std.image.unload(first + 1)
    assert(not std.image.exists(first + 1))
    assert(std.image.exists(first) and std.image.exists(first + 2))

    assert(std.image.load(url, 3) == first)
    env.loop()
    assert(#env.requests == 1)
    std.image.unload_all()
end

function test_remote_zcis_sheet_keeps_the_first_load()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/first-wins.zcis?format=zcis'

    local alone = std.image.load(url)
    assert(std.image.load(url, 3) == alone)

    env.loop()
    assert(#env.requests == 1)
    env.requests[1].success_handler({http = {body = sheet_body()}})
    for _ = 1, 8 do
        env.loop()
    end
    assert(std.image.exists(alone))
    assert(not std.image.exists(alone + 1))
    std.image.unload_all()

    local first = std.image.load(url, 3)
    assert(std.image.load(url, 9) == first)
    assert(std.image.load(url) == first)
    std.image.unload_all()
end

function test_remote_zcis_sheet_counts_below_two_are_one()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/none.zcis'

    local first = std.image.load(url, 0)
    assert(first and not std.image.exists(first + 1))
    assert(std.image.error(first) == nil)

    env.loop()
    assert(#env.requests == 1)
    std.image.unload_all()
end

function test_remote_image_without_http_yet()
    local canvas = {}
    function canvas.new()
        return {}
    end

    local loop
    local std = {
        image = {},
        bus = {
            listen = function(_, handler)
                loop = handler
            end
        }
    }

    draw_image.install(std, {canvas = canvas, offset_x = 0, offset_y = 0})
    std.image.unload_all()

    local url = 'http://localhost/late.zcis'
    local first, ready = std.image.load(url, 3)
    assert(first and ready == false)
    assert(std.image.error(first) == 'remote images need http')
    assert(std.image.error(first + 2) == 'remote images need http')
    loop()

    std.image.unload_all()
    std.http = {
        get = function()
            local request = {}
            function request:success()
                return self
            end
            function request:failed()
                return self
            end
            function request:error()
                return self
            end
            function request:run() end
            return request
        end
    }
    local late = std.image.load(url, 3)
    assert(select(2, std.image.load(url, 3)) == false)
    assert(std.image.error(late) == nil)
    loop()
    std.image.unload_all()
end

function test_image_alias_by_id()
    local env = sheet_engine()
    local std = env.std
    local url = 'http://localhost/alias.zcis?format=zcis'

    local first = std.image.load(url, 3)
    local middle = 'id://'..(first + 1)
    local last = 'id://'..(first + 2)

    assert(std.image.load('id://'..first) == first)
    assert(std.image.load(last) == first + 2)
    assert(not std.image.exists(middle))
    assert(std.image.error(middle) == nil)
    assert(not std.image.exists('id://999'))

    env.loop()
    assert(#env.requests == 1)
    env.requests[1].success_handler({http = {body = sheet_body()}})
    for _ = 1, 8 do
        env.loop()
    end

    assert(std.image.exists(middle))
    local width, height = std.image.mensure(last)
    assert(width == 2 and height == 1)

    std.image.draw(last, 5, 6)
    assert(env.canvas.composed[1] == 5 and env.canvas.composed[2] == 6)

    std.image.unload(middle)
    assert(not std.image.exists(middle))
    assert(std.image.exists(last))
    std.image.unload_all()
end

test.unit(_G)
