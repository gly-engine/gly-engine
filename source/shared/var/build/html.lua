local version = require('source/version')

local function atobify(args, text, render)
    local result = render and render(text) or text or true
    local in_html5 = args.core:match('html5') ~= nil
    local in_legacy = ('webos tizen ginga offline'):match(args.core:gsub('html5_', '')) ~= nil
    local by_core = in_html5 and in_legacy
    return by_core and result
end

local function src_engine(args)
    if args.enginecdn then
        local c1, c2, s1, s2 = (args.engine or ''):gsub('/', '_'), args.core or '', '_micro', '_lite'
        local suffix = (c1:match(s1) or c1:match(s2) or c2:match(s1) or c2:match(s2) or ''):gsub('_', '-')
        return 'https://cdn.jsdelivr.net/npm/@gamely/gly-engine'..suffix..'@'..version..'/dist/main.lua'
    elseif atobify(args) then
        return '${window.engine_code}'
    end
    return 'main.lua'
end

local function src_game(args)
    if atobify(args) then
        return '${window.game_code}'
    end
    return 'game.lua'
end

local function lib_resize(args)
    if not args.screen then
        return 'resize'
    end
    return 'none'
end

local P = {
    atobify = atobify,
    src_game = src_game,
    src_engine = src_engine,
    lib_resize = lib_resize
}

return P