--! @todo need organize this file.
local png_validator = require('source/shared/image/check_png')
local decoder_ppm = require('source/shared/image/decoder_ppm')
local decoder_y4m = require('source/shared/image/decoder_y4m')
local encoder_canvas = require('source/shared/image/enconde_canvas')
local creater_counter = require('source/shared/functional/counter')

local nextId, clearId, clearAll = creater_counter()

local image_ids = {}
local image_error = {}
local image_canvas = {}

local function load_png(std, engine, canvas, src)
    local is_userdata = type(src) == 'userdata'
    local key = src and tostring(src)
    if not key or #key == 0 then return false end
    return std.mem.cache('image'..key, function()
        if not is_userdata and not png_validator.check_error(src) then return false end
        local ok, texture = pcall(canvas.new, canvas, src)
        return (ok and texture) or false
    end)
end

local function image_load(std, engine, canvas)
    return function(src)
        local key = tostring(src)
        local id = image_ids[key]
        
        if id then 
            return id, image_canvas[id] ~= nil 
        end

        local is_userdata = type(src) == 'userdata'
        local is_httplink = src:find('^https?://')
        
        id = nextId()
        image_ids[key] = id

        if is_httplink and not std.http then
            image_error[id] = 'remote images need require=\'http\' in configs'
            return id, false
        end
        
        if not is_userdata and not is_httplink and not png_validator.check_error(src) then
            image_error[id] = 'invalid png'
            return id, false
        end

        if is_httplink then
            local decode_image = function(std)
                local decoder = decoder_y4m.new('rgba')
                local buffer = std.http.body

                decoder:push(buffer)
                
                while not decoder:is_done() do
                    decoder:step(100)
                end

                local ops = {
                    start = function(width, height)
                        return canvas.new(canvas, width, height)
                    end,
                    color = function(self, r, g, b, a)
                        canvas.attrColor(self, r, g, b, a)
                    end,
                    pixel = function(self, x, y, w, h)
                        canvas.drawRect(self, 'fill', x, y, w, h)
                    end
                }

                local width, height = decoder:mensure()
                local encoder = encoder_canvas.new(width, height, 4, ops)

                local rgba = decoder:close()
                encoder:push(rgba)

                while not encoder:is_done() do
                    encoder:step(100)
                end

                image_canvas[id] = encoder:close() 
                image_canvas[id]:flush()
            end

            local set_error = function(std)
                image_error[id] = std.http.error or tostring(std.http.status)
            end

            std.http.get(src)
                :success(decode_image)
                :failed(set_error)
                :error(set_error)
                :run()
        end

        local ok, texture = pcall(canvas.new, canvas, src)

        if not ok then
            image_error[id] = texture
            return id, false
        end

        image_canvas[id] = texture
        return id, true
    end
end

local function image_draw(std, engine, canvas)
    return function(src, pos_x, pos_y)
        local id = image_load(std, engine, canvas)(src)
        local image = image_canvas[id] 
        if image then
            local x = engine.offset_x + (pos_x or 0)
            local y = engine.offset_y + (pos_y or 0)
            canvas:compose(x, y, image)
        end
    end  
end

local function image_mensure(std, engine, canvas)
    return function(src)
        local id = image_load(std, engine, canvas)(src)
        local image = image_canvas[id] 
        if image then
            local w, h = image:attrSize()
            return w, h
        end
        return nil
    end
end

local function image_exists(std, engine, canvas)
    return function(src)
        return true
        --return not not load_png(std, engine, canvas, src)
    end
end

local function get_image_error(src)
    local key = tostring(src)
    local id = image_ids[key]
    return id and image_error[id]
end

local function install(std, engine)
    std.image.load = image_load(std, engine, engine.canvas)
    std.image.draw = image_draw(std, engine, engine.canvas)
    std.image.exists = image_exists(std, engine, engine.canvas)
    std.image.mensure = image_mensure(std, engine, engine.canvas)
    std.image.error = get_image_error
    --! @todo
    std.image.unload = function() end
    std.image.unload_all = function() end
    std.image.mensure_width = function(v) return select(1, std.image.mensure(v)) end
    std.image.mensure_height = function(v) return select(2, std.image.mensure(v)) end
end

return {
    install = install
}
