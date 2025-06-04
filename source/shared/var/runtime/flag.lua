local function screen_ginga(args)
    if args and args.screen then
        return '-s '..args.screen
    end
    return ''
end

local function screen_love(args)
    if args and args.screen then
        return '--screen '..args.screen
    end
    return ''
end

local P = {
    screen_ginga = screen_ginga,
    screen_love = screen_love
}

return P
