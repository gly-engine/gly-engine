local function loop(std, engine, dt)
    std.delta = dt * 1000
    std.milis = love.timer.getTime() * 1000
    engine.fps = love.timer.getFPS()
end

local function event_bus(std)
    std.bus.listen_std_engine('pre_loop', loop)
end

local function install(std, game, application)
end

local P = {
    event_bus=event_bus,
    install=install
}

return P
