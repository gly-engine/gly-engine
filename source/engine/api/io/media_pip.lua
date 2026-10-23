local function clamp(value, minv, maxv)
    if value < minv then return minv end
    if value > maxv then return maxv end
    return value
end

local function pip_create(std, engine)
    return function(x, y, w, h)
        x = math.floor(tonumber(x) or 0)
        y = math.floor(tonumber(y) or 0)
        w = math.floor(tonumber(w) or 0)
        h = math.floor(tonumber(h) or 0)

        local screenW = std.app.width or engine.canvas:attrSize()
        local screenH = std.app.height or select(2, engine.canvas:attrSize())

        x = clamp(x, 0, screenW)
        y = clamp(y, 0, screenH)
        w = clamp(w, 0, screenW - x)
        h = clamp(h, 0, screenH - y)


        engine.pip = { x = x, y = y, w = w, h = h }

        if y > 0 then
            engine.canvasgly[1] = engine.canvas:new(screenW, y)
        end

        if x > 0 then
            engine.canvasgly[2] = engine.canvas:new(x, h)
        end

        if x + w < screenW then
            engine.canvasgly[3] = engine.canvas:new(screenW - (x + w), h)
        end

        if y + h < screenH then
            engine.canvasgly[4] = engine.canvas:new(screenW, screenH - (y + h))
        end
    end
end

local function install(std, engine)
    std.media = std.media or {}
    std.media.pip = pip_create(std, engine)
end

local P = {
    install = install
}

return P