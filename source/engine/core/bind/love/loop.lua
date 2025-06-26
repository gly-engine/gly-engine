local function loop(std, engine, dt)
    std.delta = dt * 1000
    std.milis = love.timer.getTime() * 1000
    engine.fps = love.timer.getFPS()
end

local function install(std, game, application)
    std.bus.listen_std_engine('pre_loop', loop)
end

local P = {
    install=install
}

return P
