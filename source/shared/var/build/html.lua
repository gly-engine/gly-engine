local version = require('source/version')
local core_version = '0.3'

local function atobify(args, text, render)
    local falsy = render and '' or false 
    local result = render and render(text) or text or true
    local in_html5 = args.core:match('html5') ~= nil
    local in_legacy = ('webos tizen ginga offline'):match(args.core:gsub('html5_', '')) ~= nil
    local by_core = in_html5 and in_legacy
    local by_flag = args.atob or args.atobify
    return (by_core or by_flag) and result or falsy
end

--! @return javascript expression with url or code of the engine
local function src_engine(args)
    if args.enginecdn then
        local c1, c2, s1, s2 = (args.engine or ''):gsub('/', '_'), args.core or '', '_micro', '_lite'
        local suffix = (c1:match(s1) or c1:match(s2) or c2:match(s1) or c2:match(s2) or ''):gsub('_', '-')
        return "'https://cdn.jsdelivr.net/npm/@gamely/gly-engine"..suffix..'@'..version.."/dist/main.lua'"
    elseif atobify(args) then
        return 'window.engine_code'
    end
    return "'main.lua'"
end

--! @return javascript expression with url or code of the game
local function src_game(args)
    if atobify(args) then
        return 'window.game_code'
    end
    return "'game.lua'"
end

local function src_core(args)
    if args.corecdn then
        local vm = args.fengari and 'fengari' or 'wasmoon'
        return 'https://cdn.jsdelivr.net/npm/@gamely/core-native-html5@'..core_version..'/dist/'..vm..'.js'
    end
    return 'core-native.js'
end

local P = {
    atobify = atobify,
    src_game = src_game,
    src_core = src_core,
    src_engine = src_engine
}

return P