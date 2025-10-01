local function to_uint32_be(s)
    local b1,b2,b3,b4 = s:byte(1,4)
    return ((b1*256+b2)*256+b3)*256+b4
end

local function check_png(path)
    local f = io.open(path,"rb")
    if not f then return false end

    if f:read(8) ~= "\137PNG\r\n\26\n" then
        f:close()
        return false
    end

    while true do
        local len_bytes = f:read(4)
        if not len_bytes or #len_bytes<4 then break end

        local length = to_uint32_be(len_bytes)
        local ctype = f:read(4)
        if not ctype or #ctype<4 then f:close(); return false end

        local data = f:read(length)
        if not data or #data<length then f:close(); return false end

        if not f:read(4) then f:close(); return false end

        if ctype == "IEND" then
            if not f:read(1) then
                f:close()
                return true
            else
                f:close()
                return false
            end
        end
    end

    f:close()
    return false
end

local function load_png(std, engine, canvas, src)
    if not src or #src == 0 then return false end
    return std.mem.cache('image'..src, function()
        if not check_png(src) then return false end
        local ok, texture = pcall(canvas.new, canvas, src)
        return (ok and texture) or false
    end)
end

local function image_draw(std, engine, canvas)
    return function(src, pos_x, pos_y)
        local image = load_png(std, engine, canvas, src)
        if image then
            local x = engine.offset_x + (pos_x or 0)
            local y = engine.offset_y + (pos_y or 0)
            canvas:compose(x, y, image)
        end
    end  
end

local function image_mensure(std, engine, canvas)
    return function(src)
        local image = load_png(std, engine, canvas, src)
        if image then
            local w, h = image:attrSize()
            return w, h
        end
        return nil
    end
end

local function image_exists(std, engine, canvas)
    return function(src)
        return not not load_png(std, engine, canvas, src)
    end
end

local function install(std, engine)
    std.image.draw = image_draw(std, engine, engine.canvas)
    std.image.exists = image_exists(std, engine, engine.canvas)
    std.image.mensure = image_mensure(std, engine, engine.canvas)
end

return {
    install = install
}
