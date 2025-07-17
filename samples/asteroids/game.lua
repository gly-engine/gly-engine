--! @par Game FSM
--! @startuml
--! hide empty description
--! state 1 as "menu"
--! state 2 as "credits"
--! state 3 as "game_spawn"
--! state 4 as "game_play"
--! state 5 as "game_player_dead"
--! state 6 as "game_player_win"
--! state 7 as "game_over"
--! state 8 as "menu"
--! 
--! [*] -> 1
--! 1 ---> 2
--! 1 --> 3
--! 2 --> 1
--! 3 --> 4
--! 4 --> 5
--! 4 --> 6
--! 5 --> 3
--! 5 --> 7
--! 6 --> 3
--! 7 --> [*]
--! 
--! 4 -> 8: pause
--! 8 -> 4: resume
--! @enduml

local function i18n(std, game)
    return {
        ['pt-BR'] = {
            ['lifes:'] = 'vidas:',
            ['Continue'] = 'Continuar',
            ['New Game'] = 'Novo Jogo',
            ['Dificulty'] = 'Dificuldade',
            ['Invincibility'] = 'Imortabilidade',
            ['Object Limit'] = 'Limitador',
            ['Graphics'] = 'Graficos',
            ['fast'] = 'rapido',
            ['pretty'] = 'bonito',
            ['Language'] = 'Idioma',
            ['Credits'] = 'Creditos',
            ['Exit'] = 'Sair'
        }
    }
end

local function draw_logo(std, game, height, anim)
    anim = anim or 0
    std.text.font_size(std.math.max(game.height/24, game.width/36, 4))
    std.draw.color(std.color.white)
    local s1 = std.text.mensure('AsteroidsTv')
    local s2 = std.text.mensure('Tv')
    std.text.print(game.width/2 - s1/2, height + anim, 'Asteroids')
    std.draw.color(std.color.red)
    std.text.print(game.width/2 + s1/2 - s2, height - anim, 'Tv')
    return s1
end

local function intersect_line_circle(x1, y1, x2, y2, h, k, raio)
    local m = (y2 - y1) / (x2 - x1)
    local c = y1 - m * x1
    local A = 1 + m^2
    local B = 2 * (m * c - m * k - h)
    local C = h^2 + k^2 + c^2 - 2 * c * k - raio^2
    local discriminante = B^2 - 4 * A * C
    return discriminante >= 0
end

local function asteroid_fragments(game, size, level)
    -- level 1,2,3
    if size == game.asteroid_small_mini then return 0, -1, 50 end
    if size == game.asteroid_small_size and level <=3 then return 0, -1, 15 end
    if size == game.asteroid_mid_size and level <= 3 then return 2, game.asteroid_small_size, 10 end				
    if size == game.asteroid_large_size and level <= 3 then return 1, game.asteroid_mid_size, 5 end
    -- level 4,5,6
    if size == game.asteroid_small_size and level <= 6 then return 1, game.asteroid_mini_size, 20 end
    if size == game.asteroid_mid_size and level <= 6 then return 2, game.asteroid_small_size, 15 end
    if size == game.asteroid_large_size and level <= 6 then return 1, game.asteroid_mid_size, 10 end
    -- level 7,8,9
    if size == game.asteroid_small_size and level <= 9 then return 1, game.asteroid_mini_size, 25 end
    if size ==  game.asteroid_mid_size and level <= 9 then return 3, game.asteroid_small_size, 20 end
    if size == game.asteroid_large_size and level <= 9 then return 1,  game.asteroid_mid_size, 15 end
    -- level 10... all asteroids
    if size == game.asteroid_small_size then return 1, game.asteroid_mini_size, 40 end
    if size == game.asteroid_mid_size then return 3, game.asteroid_small_size, 30 end
    if size == game.asteroid_large_size then return 2, game.asteroid_mid_size, 20 end
    return 0, -1, 0
end

local function asteroid_nest(std, game, x, y, id)
    local index = 1
    while index < #game.asteroid_size do
        if index ~= id  and game.asteroid_size[index] ~= -1 then
            local size = game.asteroid_size[index] / 2
            local distance = std.math.dis(x, y, game.asteroid_pos_x[index] + size, game.asteroid_pos_y[index] + size)
            if distance <= size then
                return true
            end
        end
        index = index + 1
    end
    return false
end

local function asteroids_resize(std, game)
    if (game.width <= 400) then
        local div = function(v) return std.math.ceil(v * (game.width/800)) end
        game.asteroid_large = std.array.map(game.asteroid_large, div)
        game.asteroid_mid = std.array.map(game.asteroid_mid, div)
        game.asteroid_small = std.array.map(game.asteroid_small, div)
        game.asteroid_mini = std.array.map(game.asteroid_mini, div)
    end
end

local function asteroids_rain(std, game)
    local index = 1
    local attemps = 1
    local n1 = 0.5 * std.math.min(game.level/3, 1)
    local n2 = 1.0 * std.math.min(game.level/3, 1)
    local n3 = 2.0 * std.math.min(game.level/3, 1)
    local n4 = 2.5 * std.math.min(game.level/3, 1)
    local hspeed = {-n1, 0, 0, 0, 0, 0, n1}
    local vspeed = {-n4, -n3, -n2, n2, n3, n4}
    local middle_left = game.width/4
    local middle_right = game.width/4 * 3

    while index <= game.asteroids_max and index <= 10 do
        repeat
            local success = true
            attemps = attemps + 1
            game.asteroid_size[index] = game.asteroid_large_size
            game.asteroid_pos_x[index] = std.math.random(1, game.width)
            game.asteroid_pos_y[index] = std.math.random(1, game.height)
            game.asteroid_spd_x[index] = hspeed[std.math.random(1, #hspeed)]
            game.asteroid_spd_y[index] = vspeed[std.math.random(1, #vspeed)]

            if game.asteroid_pos_x[index] > middle_left and game.asteroid_pos_x[index] < middle_right then
                success = false
            end

            if asteroid_nest(std, game, game.asteroid_pos_x[index], game.asteroid_pos_x[index], index) then
                success = false
            end

            if attemps > 100 then
                success = true
            end
        until success
        index = index + 1
    end
end

local function asteroid_destroy(std, game, id)
    local index = 1
    local hspeed = {-1, 1}
    local vspeed = {-2, -1, 1, 2}
    local asteroids = #game.asteroid_size
    local original_size = game.asteroid_size[id]
    local fragments, size, score = asteroid_fragments(game, original_size, game.level)
    
    game.asteroid_size[id] = -1

    while index <= fragments and (game.asteroids_count + index) <= (game.asteroids_max + 1) do
        game.asteroid_size[asteroids + index] = size
        game.asteroid_pos_x[asteroids + index] = game.asteroid_pos_x[id]
        game.asteroid_pos_y[asteroids + index] = game.asteroid_pos_y[id]
        game.asteroid_spd_x[asteroids + index] = hspeed[std.math.random(1, #hspeed)] * std.math.min(game.level/5, 1)
        game.asteroid_spd_y[asteroids + index] = vspeed[std.math.random(1, #vspeed)] * std.math.min(game.level/5, 1)
        index = index + 1
    end

    return score
end

local function init(std, game)
    -- game
    game.boost = 0.12
    game.speed_max = 5
    game.asteroids_count = 0
    -- configs
    game.state = game.state or 1
    game.lifes = game.lifes or 3
    game.level = game.level or 1
    game.score = game.score or 0
    game.imortal = game.imortal or 0
    game.highscore = game.highscore or 0
    game.asteroids_max = game.asteroids_max or 60
    game.graphics_fastest = game.graphics_fastest or 0
    -- player
    game.player_size = std.math.clamp(game.width/100, 1, 3)
    game.player_pos_x = game.width/2
    game.player_pos_y = game.height/2
    game.player_spd_x = 0
    game.player_spd_y = 0
    game.player_angle = 0
    game.player_last_teleport = 0
    -- cannon
    game.laser_enabled = false
    game.laser_pos_x1 = 0
    game.laser_pos_y1 = 0
    game.laser_pos_x2 = 0
    game.laser_pos_y2 = 0
    game.laser_last_fire = 0
    game.laser_time_fire = 50
    game.laser_time_recharge = 300
    game.laser_distance_fire = 300
    -- asteroids
    game.asteroid_pos_x = {}
    game.asteroid_pos_y = {}
    game.asteroid_spd_x = {}
    game.asteroid_spd_y = {}
    game.asteroid_size = {}
    -- polys
    game.asteroid_large = {27, 0, 27, 15, 15, 12, 0, 30, 18, 39, 9, 48, 15, 60, 30, 66, 48, 66, 57, 57, 60, 51, 66, 42, 66, 33, 54, 12}
    game.asteroid_mid = {6, 0, 0, 21, 9, 33, 9, 48, 24, 51, 36, 45, 48, 42, 36, 12, 48, 3, 18, 0}
    game.asteroid_small = {3, 0, 0, 3, 3, 9, 3, 12, 0, 18, 6, 21, 12, 21, 18, 18, 21, 15, 21, 3, 12, 3, 9, 6}
    game.asteroid_mini = {6, 0, 6, 6, 0, 6, 0, 12, 3, 18, 6, 18, 6, 15, 15, 15, 18, 9, 12, 6, 12, 0}
    game.spaceship = {-2,3, 0,-2, 2,3}
    asteroids_resize(std, game)
    -- sizes
    game.asteroid_large_size = std.math.max(game.asteroid_large)
    game.asteroid_mid_size = std.math.max(game.asteroid_mid)
    game.asteroid_small_size = std.math.max(game.asteroid_small)
    game.asteroid_mini_size = std.math.max(game.asteroid_mini)
    -- menu
    game.menu = 2
    game.menu_time = 0
    -- start
    asteroids_rain(std, game)
end

local function loop(std, game)
    if game.state == 1 then
        local keyh = std.key.axis.x + std.key.axis.a 
        if std.key.axis.y ~= 0 and std.milis > game.menu_time + 250 then
            game.menu = std.math.clamp(game.menu + std.key.axis.y, game.player_pos_x == (game.width/2) and 2 or 1, 9)
            game.menu_time = std.milis
        end
        if keyh ~= 0 and std.milis > game.menu_time + 100 then
            game.menu_time = std.milis
            if game.menu == 1 then
                game.state = 4
            elseif game.menu == 2 then
                std.app.reset()
                game.state = 4
                game.score = 0
            elseif game.menu == 3 then
                game.level = std.math.clamp2(game.level + keyh, 1, 99)
            elseif game.menu == 4 then
                game.imortal = std.math.clamp(game.imortal + keyh, 0, 1)
            elseif game.menu == 5 then
                game.asteroids_max = std.math.clamp2(game.asteroids_max + keyh, 5, 60)
            elseif game.menu == 6 then
                game.graphics_fastest = std.math.clamp(game.graphics_fastest + keyh, 0, 1)
                game.fps_max = 100
            elseif game.menu == 7 then
                std.i18n.next()
            elseif game.menu == 8 then
                game.state = 2
            elseif game.menu == 9 then
                std.app.exit()
            end
        end
        return
    elseif game.state == 2 and (std.key.press.d or std.key.press.menu) then
        game.menu_time = std.milis
        game.state = 1
        return
    end
    -- enter in the menu
    if std.key.press.d or std.key.press.menu then
        game.state = 1
    end
    -- player move
    game.player_angle = (game.player_angle + (std.key.axis.x * 0.1)) % (std.math.pi * 2)
    game.player_pos_x = game.player_pos_x + (game.player_spd_x/16 * std.delta)
    game.player_pos_y = game.player_pos_y + (game.player_spd_y/16 * std.delta)
    if not (std.key.press.up or std.key.press.b) and (std.math.abs(game.player_spd_x) + std.math.abs(game.player_spd_y)) < 0.45 then
        game.player_spd_x = 0
        game.player_spd_y = 0
    end
    if std.key.press.up or std.key.press.b then
        game.player_spd_x = game.player_spd_x + (game.boost * std.math.cos(game.player_angle - std.math.pi/2))
        game.player_spd_y = game.player_spd_y + (game.boost * std.math.sin(game.player_angle - std.math.pi/2))
        local max_spd_x = std.math.abs(game.speed_max * std.math.cos(game.player_angle - std.math.pi/2))
        local max_spd_y = std.math.abs(game.speed_max * std.math.sin(game.player_angle - std.math.pi/2))
        game.player_spd_x = std.math.clamp(game.player_spd_x, -max_spd_x, max_spd_x) 
        game.player_spd_y = std.math.clamp(game.player_spd_y, -max_spd_y, max_spd_y)
    end
    if game.player_pos_y < 3 then
        game.player_pos_y = game.height
    end
    if game.player_pos_x < 3 then
        game.player_pos_x = game.width
    end
    if game.player_pos_y > game.height then
        game.player_pos_y = 3
    end
    if game.player_pos_x > game.width then
        game.player_pos_x = 3
    end
    -- player teleport
    if (std.key.press.down or std.key.press.c) and std.milis > game.player_last_teleport + 1000 then
        game.player_last_teleport = std.milis
        game.laser_pos_x1 = game.player_pos_x
        game.laser_pos_y1 = game.player_pos_y 
        game.player_spd_x = 0
        game.player_spd_y = 0
        repeat
            game.player_pos_x = std.math.random(1, game.width)
            game.player_pos_y = std.math.random(1, game.height)
        until not asteroid_nest(std, game, game.player_pos_x, game.player_pos_y, -1)
    end
    -- player shoot
    if not game.laser_enabled and game.state == 4 and std.key.press.a then
        local index = 1
        local asteroids = #game.asteroid_size
        local sin = std.math.cos(game.player_angle - std.math.pi/2)
        local cos = std.math.sin(game.player_angle - std.math.pi/2)
        local laser_fake_x = game.player_pos_x - (game.laser_distance_fire * sin)
        local laser_fake_y = game.player_pos_y - (game.laser_distance_fire * cos)
        game.laser_pos_x2 = game.player_pos_x + (game.laser_distance_fire * sin)
        game.laser_pos_y2 = game.player_pos_y + (game.laser_distance_fire * cos)
        game.laser_pos_x1 = game.player_pos_x + (12 * sin)
        game.laser_pos_y1 = game.player_pos_y + (12 * cos)
        game.laser_last_fire = std.milis
        game.laser_enabled = true
        while index <= asteroids do
            if game.asteroid_size[index] ~= -1 then
                local size = game.asteroid_size[index]/2
                local x = game.asteroid_pos_x[index] + size
                local y = game.asteroid_pos_y[index] + size
                local dis_p1 = std.math.dis(game.laser_pos_x1, game.laser_pos_y1, x,y)
                local dis_p2 = std.math.dis(game.laser_pos_x2, game.laser_pos_y2, x,y)
                local dis_fake = std.math.dis(laser_fake_x, laser_fake_y, x,y)
                local intersect = intersect_line_circle(game.laser_pos_x1, game.laser_pos_y1, game.laser_pos_x2, game.laser_pos_y2, x, y, size*2)
                if intersect and dis_p2 < dis_fake and dis_p1 < game.laser_distance_fire then
                    game.score = game.score + asteroid_destroy(std, game, index)
                end
            end
            index = index + 1
        end
    end
    if game.laser_enabled and std.milis > game.laser_last_fire + game.laser_time_recharge then
        game.laser_enabled = false
    end
    -- player death
    if game.imortal ~= 1 and game.state == 4 and asteroid_nest(std, game, game.player_pos_x, game.player_pos_y, -1) then
        game.menu_time = std.milis
        game.lifes = game.lifes - 1
        game.state = 5
    end
    -- asteroids move
    local index = 1
    game.asteroids_count = 0
    while index <= #game.asteroid_size do
        if game.asteroid_size[index] ~= -1 then
            game.asteroids_count = game.asteroids_count + 1
            game.asteroid_pos_x[index] = game.asteroid_pos_x[index] + game.asteroid_spd_x[index]
            game.asteroid_pos_y[index] = game.asteroid_pos_y[index] + game.asteroid_spd_y[index]
            if game.asteroid_pos_y[index] < 1 then
                game.asteroid_pos_y[index] = game.height
            end
            if game.asteroid_pos_x[index] < 1 then
                game.asteroid_pos_x[index] = game.width
            end
            if game.asteroid_pos_y[index] > game.height then
                game.asteroid_pos_y[index] = 1
            end
            if game.asteroid_pos_x[index] > game.width then
                game.asteroid_pos_x[index] = 1
            end
        end
        index = index + 1
    end
    -- next level
    if game.state == 4 and game.asteroids_count == 0 then
        game.menu_time = std.milis
        game.state = 6
    end
    if game.state == 6 and std.milis > game.menu_time + 3000 then
        std.app.reset()
        game.level = game.level + 1
        game.state = 4
    end
    -- restart 
    if game.state == 5 and std.milis > game.menu_time + 3000 then
        std.app.reset()
        game.state = 4
        if game.lifes == 0 then
            game.score = 0
            game.lifes = 3
            game.level = 1
        end
    end
end

local function draw(std, game)
    local death_anim = game.state == 5 and std.milis < game.menu_time + 50 
    std.draw.clear(death_anim and std.color.white or std.color.black)
    if game.state == 1 then
        local h = game.height/24
        local hmenu = (game.menu*h) + (h*11) - (h/3)
        local language = std.i18n.get_language()
        local graphics = game.graphics_fastest == 1 and 'fast' or 'pretty'
        local s = std.math.min(game.width/4, draw_logo(std, game, h*4))
        local w1, w2 = (game.width/2 - s), (game.width/2 + s)
        std.text.font_size(h/2)
        std.draw.color(std.color.white)
        if game.player_pos_x ~= (game.width/2) then
            std.text.print(game.width/2 - s, h*11, 'Continue')
        end
        std.text.print(w1, h*12, 'New Game')
        std.text.print(w1, h*13, 'Dificulty')
        std.text.print(w1, h*14, 'Invincibility')
        std.text.print(w1, h*15, 'Object Limit')
        std.text.print(w1, h*16, 'Graphics')
        std.text.print(w1, h*17, 'Language')
        std.text.print(w1, h*18, 'Credits')
        std.text.print(w1, h*19, 'Exit')
        std.draw.line(w1, hmenu, w2, hmenu)
        std.draw.color(std.color.red)
        std.text.print_ex(w2, h*13, game.level, -1)
        std.text.print_ex(w2, h*14, game.imortal, -1)
        std.text.print_ex(w2, h*15, game.asteroids_max, -1)
        std.text.print_ex(w2, h*16, graphics, -1)
        std.text.print_ex(w2, h*17, language, -1)
        return
    elseif game.state == 2 then
        local height = game.height/4
        local anim = std.math.cos(std.milis/100) * 5
        draw_logo(std, game, height, anim) 
        std.text.font_size(16)
        std.draw.color(std.color.white)
        std.text.print_ex(game.width/2 + anim, height*2, 'Rodrigo Dornelles', 0)
        return
    end
    -- draw asteroids
    std.draw.color(std.color.white)
    local index = 1
    while index <= #game.asteroid_size do
        if game.asteroid_size[index] ~= -1 then
            if game.graphics_fastest == 1 then
                local s = game.asteroid_size[index]
                std.draw.rect(1, game.asteroid_pos_x[index], game.asteroid_pos_y[index], s, s)
            elseif game.asteroid_size[index] == game.asteroid_large_size then
                std.draw.poly(1, game.asteroid_large, game.asteroid_pos_x[index], game.asteroid_pos_y[index])
            elseif game.asteroid_size[index] == game.asteroid_mid_size then
                std.draw.poly(1, game.asteroid_mid, game.asteroid_pos_x[index], game.asteroid_pos_y[index])
            elseif game.asteroid_size[index] == game.asteroid_small_size then
                std.draw.poly(1, game.asteroid_small, game.asteroid_pos_x[index], game.asteroid_pos_y[index])
            else
                std.draw.poly(1, game.asteroid_mini, game.asteroid_pos_x[index], game.asteroid_pos_y[index])
            end
        end
        index = index + 1
    end
    -- draw player
    if game.state ~= 5 then
        -- triangle
        std.draw.color(std.color.yellow)
        std.draw.poly(2, game.spaceship, game.player_pos_x, game.player_pos_y, game.player_size, game.player_angle)
        -- laser bean
        if game.laser_enabled and std.milis < game.laser_last_fire + game.laser_time_fire then
            std.draw.color(std.color.green)
            std.draw.line(game.laser_pos_x1, game.laser_pos_y1, game.laser_pos_x2, game.laser_pos_y2)
        end
        std.draw.color(std.color.red)
        -- boost
        if std.key.press.up or std.key.press.b  then
            local s = std.math.random(4, 12)
            local sin = std.math.cos(game.player_angle - std.math.pi/2)
            local cos = std.math.sin(game.player_angle - std.math.pi/2)
            local x = game.player_pos_x - (sin * (s + 12)) - (s/2)
            local y = game.player_pos_y - (cos * (s + 12)) - (s/2)
            std.draw.rect(1, x, y, s, s)
        end
        -- teleport
        if std.milis < game.player_last_teleport + 100 then
            std.draw.line(game.laser_pos_x1, game.laser_pos_y1, game.player_pos_x, game.player_pos_y)
        end
    end
    -- draw gui
    local w, h = std.text.mensure('a')
    local t = (game.width < 400 and not std.text.is_tui()) and (h*2) or 2
    w = game.width/6
    std.draw.color(std.color.black)
    std.draw.rect(0, 0, 0, game.width, h)
    std.draw.color(std.color.white)
    std.text.print_ex(w*1, 2, 'lifes: '..tostring(game.lifes), 0)
    std.text.print_ex(w*2, t, 'level: '..tostring(game.level), 0)
    std.text.print_ex(w*3, 2, 'asteroids: '..tostring(game.asteroids_count), 0)
    std.text.print_ex(w*4, t, 'score: '..tostring(game.score), 0)
    std.text.print_ex(w*5, 2, 'highscore: '..tostring(game.highscore), 0)
end

local function exit(std, game)
    game.highscore = std.math.max(game.score, game.highscore)
    game.asteroid_pos_x = nil
    game.asteroid_pos_y = nil
    game.asteroid_spd_x = nil
    game.asteroid_spd_y = nil
    game.asteroid_size = nil
    game.asteroid_large = nil
    game.asteroid_mid =  nil
    game.asteroid_small = nil
    game.asteroid_mini = nil
end

local P = {
    meta={
        id='br.com.gamely.asteroids',
        title='AsteroidsTV',
        author='RodrigoDornelles',
        description='similar to the original but with lasers because televisions may have limited hardware.',
        tizen_package='3202411037732',
        version='1.0.0'
    },
    config = {
        require = 'math math.random i18n'
    },
    callbacks={
        i18n=i18n,
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P;
