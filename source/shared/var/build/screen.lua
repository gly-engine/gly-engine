
local function has_flag(args, text, render)
    local result = render and render(text) or text or true
    return (args.screen or ''):find('%d+x%d') and result
end

local function width(args)
    return (args.screen or ''):match('(%d+)x%d')
end

local function height(args)
    return (args.screen or ''):match('%d+x(%d+)')
end

local function wh_attributes(args)
    local width, height = width(args), height(args)
    if width and height then
        return 'width="'..width..'" height="'..height..'"'
    end
    return ''
end

local P = {
    width = width,
    height = height,
    has_flag = has_flag,
    wh_attributes = wh_attributes,
}

return P
