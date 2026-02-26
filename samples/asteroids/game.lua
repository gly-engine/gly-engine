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

local function v2s(self, vx, vy)
    return self.off_x + vx * self.scale, self.off_y + (vy + self.GUI_H) * self.scale
end

local function v2s_size(self, s)
    return s * self.scale
end

local function i18n(self, std)
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

local function draw_logo(self, std, height, anim)
    anim = anim or 0
    std.text.font_size(std.math.max(self.height/24, self.width/36, 4))
    std.draw.color(std.color.white)
    local s1 = std.text.mensure('AsteroidsTv')
    local s2 = std.text.mensure('Tv')
    std.text.print(self.width/2 - s1/2, height + anim, 'Asteroids')
    std.draw.color(std.color.red)
    std.text.print(self.width/2 + s1/2 - s2, height - anim, 'Tv')
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

local function asteroid_fragments(self, size, level)
    -- level 1,2,3
    if size == self.asteroid_mini_size then return 0, -1, 50 end
    if size == self.asteroid_small_size and level <=3 then return 0, -1, 15 end
    if size == self.asteroid_mid_size and level <= 3 then return 2, self.asteroid_small_size, 10 end				
    if size == self.asteroid_large_size and level <= 3 then return 1, self.asteroid_mid_size, 5 end
    -- level 4,5,6
    if size == self.asteroid_small_size and level <= 6 then return 1, self.asteroid_mini_size, 20 end
    if size == self.asteroid_mid_size and level <= 6 then return 2, self.asteroid_small_size, 15 end
    if size == self.asteroid_large_size and level <= 6 then return 1, self.asteroid_mid_size, 10 end
    -- level 7,8,9
    if size == self.asteroid_small_size and level <= 9 then return 1, self.asteroid_mini_size, 25 end
    if size ==  self.asteroid_mid_size and level <= 9 then return 3, self.asteroid_small_size, 20 end
    if size == self.asteroid_large_size and level <= 9 then return 1,  self.asteroid_mid_size, 15 end
    -- level 10... all asteroids
    if size == self.asteroid_small_size then return 1, self.asteroid_mini_size, 40 end
    if size == self.asteroid_mid_size then return 3, self.asteroid_small_size, 30 end
    if size == self.asteroid_large_size then return 2, self.asteroid_mid_size, 20 end
    return 0, -1, 0
end

local function asteroid_nest(self, std, x, y, id)
    local index = 1
    while index <= #self.asteroid_size do
        if index ~= id  and self.asteroid_size[index] ~= -1 then
            local size = self.asteroid_size[index] / 2
            local distance = std.math.dis(x, y, self.asteroid_pos_x[index] + size, self.asteroid_pos_y[index] + size)
            if distance <= size then
                return true
            end
        end
        index = index + 1
    end
    return false
end

local function asteroids_rain(self, std)
    local index = 1
    local attemps = 1
    local n1 = 0.5 * std.math.min(self.level/3, 1)
    local n2 = 1.0 * std.math.min(self.level/3, 1)
    local n3 = 2.0 * std.math.min(self.level/3, 1)
    local n4 = 2.5 * std.math.min(self.level/3, 1)
    local hspeed = {-n1, 0, 0, 0, 0, 0, n1}
    local vspeed = {-n4, -n3, -n2, n2, n3, n4}
    local middle_left = self.VW/4
    local middle_right = self.VW/4 * 3

    while index <= self.asteroids_max and index <= 10 do
        repeat
            local success = true
            attemps = attemps + 1
            self.asteroid_size[index] = self.asteroid_large_size
            self.asteroid_pos_x[index] = std.math.random(1, self.VW)
            self.asteroid_pos_y[index] = std.math.random(1, self.VH)
            self.asteroid_spd_x[index] = hspeed[std.math.random(1, #hspeed)]
            self.asteroid_spd_y[index] = vspeed[std.math.random(1, #vspeed)]

            if self.asteroid_pos_x[index] > middle_left and self.asteroid_pos_x[index] < middle_right then
                success = false
            end

            if asteroid_nest(self, std, self.asteroid_pos_x[index], self.asteroid_pos_y[index], index) then
                success = false
            end

            if attemps > 100 then
                success = true
            end
        until success
        index = index + 1
    end
end

local function asteroid_destroy(self, std, id)
    local index = 1
    local hspeed = {-1, 1}
    local vspeed = {-2, -1, 1, 2}
    local asteroids = #self.asteroid_size
    local original_size = self.asteroid_size[id]
    local fragments, size, score = asteroid_fragments(self, original_size, self.level)
    
    self.asteroid_size[id] = -1

    while index <= fragments and (self.asteroids_count + index) <= (self.asteroids_max + 1) do
        self.asteroid_size[asteroids + index] = size
        self.asteroid_pos_x[asteroids + index] = self.asteroid_pos_x[id]
        self.asteroid_pos_y[asteroids + index] = self.asteroid_pos_y[id]
        self.asteroid_spd_x[asteroids + index] = hspeed[std.math.random(1, #hspeed)] * std.math.min(self.level/5, 1)
        self.asteroid_spd_y[asteroids + index] = vspeed[std.math.random(1, #vspeed)] * std.math.min(self.level/5, 1)
        index = index + 1
    end

    return score
end

local function init(self, std)
    -- resolution
    self.VW, self.VH = 1680, 720
    self.ASPECT = 16 / 9
    self.TOTAL_VH = self.VW / self.ASPECT
    self.GUI_H = (self.TOTAL_VH - self.VH) / 2

    -- physics config
    self.scale = std.math.min(self.width / self.VW, self.height / self.TOTAL_VH)
    self.off_x = (self.width - self.VW * self.scale) / 2
    self.off_y = (self.height - self.TOTAL_VH * self.scale) / 2

    -- game
    self.boost = 0.15
    self.rotation_speed = 0.06
    self.speed_max = 8
    self.asteroids_count = 0
    -- configs
    self.state = self.state or 1
    self.lifes = self.lifes or 3
    self.level = self.level or 1
    self.score = self.score or 0
    self.imortal = self.imortal or 0
    self.highscore = self.highscore or 0
    self.asteroids_max = self.asteroids_max or 60
    self.graphics_fastest = self.graphics_fastest or 0
    -- player
    self.player_size = 3
    self.player_pos_x = self.VW/2
    self.player_pos_y = self.VH/2
    self.player_spd_x = 0
    self.player_spd_y = 0
    self.player_angle = 0
    self.player_last_teleport = 0
    -- cannon
    self.laser_enabled = false
    self.laser_pos_x1 = 0
    self.laser_pos_y1 = 0
    self.laser_pos_x2 = 0
    self.laser_pos_y2 = 0
    self.laser_last_fire = 0
    self.laser_time_fire = 50
    self.laser_time_recharge = 300
    self.laser_distance_fire = 600
    -- asteroids
    self.asteroid_pos_x = {}
    self.asteroid_pos_y = {}
    self.asteroid_spd_x = {}
    self.asteroid_spd_y = {}
    self.asteroid_size = {}
    -- polys
    self.asteroid_large = {27, 0, 27, 15, 15, 12, 0, 30, 18, 39, 9, 48, 15, 60, 30, 66, 48, 66, 57, 57, 60, 51, 66, 42, 66, 33, 54, 12}
    self.asteroid_mid = {6, 0, 0, 21, 9, 33, 9, 48, 24, 51, 36, 45, 48, 42, 36, 12, 48, 3, 18, 0}
    self.asteroid_small = {3, 0, 0, 3, 3, 9, 3, 12, 0, 18, 6, 21, 12, 21, 18, 18, 21, 15, 21, 3, 12, 3, 9, 6}
    self.asteroid_mini = {6, 0, 6, 6, 0, 6, 0, 12, 3, 18, 6, 18, 6, 15, 15, 15, 18, 9, 12, 6, 12, 0}
    self.spaceship = {-2,3, 0,-2, 2,3}
    
    -- sizes
    self.asteroid_large_size = std.math.max(self.asteroid_large)
    self.asteroid_mid_size = std.math.max(self.asteroid_mid)
    self.asteroid_small_size = std.math.max(self.asteroid_small)
    self.asteroid_mini_size = std.math.max(self.asteroid_mini)
    -- menu
    self.menu = 2
    self.menu_time = 0
    -- start
    asteroids_rain(self, std)
end

local function loop(self, std)
    if self.state == 1 then
        local keyh = std.key.axis.x + std.key.axis.a 
        if std.key.axis.y ~= 0 and std.milis > self.menu_time + 250 then
            self.menu = std.math.clamp(self.menu + std.key.axis.y, self.player_pos_x == (self.VW/2) and 2 or 1, 9)
            self.menu_time = std.milis
        end
        if keyh ~= 0 and std.milis > self.menu_time + 100 then
            self.menu_time = std.milis
            if self.menu == 1 then
                self.state = 4
            elseif self.menu == 2 then
                std.app.reset()
                self.state = 4
                self.score = 0
            elseif self.menu == 3 then
                self.level = std.math.clamp2(self.level + keyh, 1, 99)
            elseif self.menu == 4 then
                self.imortal = std.math.clamp(self.imortal + keyh, 0, 1)
            elseif self.menu == 5 then
                self.asteroids_max = std.math.clamp2(self.asteroids_max + keyh, 5, 60)
            elseif self.menu == 6 then
                self.graphics_fastest = std.math.clamp(self.graphics_fastest + keyh, 0, 1)
                self.fps_max = 100
            elseif self.menu == 7 then
                std.i18n.next()
            elseif self.menu == 8 then
                self.state = 2
            elseif self.menu == 9 then
                std.app.exit()
            end
        end
        return
    elseif self.state == 2 and (std.key.press.d or std.key.press.menu) then
        self.menu_time = std.milis
        self.state = 1
        return
    end
    -- enter in the menu
    if std.key.press.d or std.key.press.menu then
        self.state = 1
    end
    -- player move
    self.player_angle = (self.player_angle + (std.key.axis.x * self.rotation_speed)) % (std.math.pi * 2)
    self.player_pos_x = self.player_pos_x + (self.player_spd_x/16 * std.delta)
    self.player_pos_y = self.player_pos_y + (self.player_spd_y/16 * std.delta)
    
    if std.key.press.up or std.key.press.b then
        self.player_spd_x = self.player_spd_x + (self.boost * std.math.cos(self.player_angle - std.math.pi/2))
        self.player_spd_y = self.player_spd_y + (self.boost * std.math.sin(self.player_angle - std.math.pi/2))
    end
    
    -- clamp speed
    local mag = (self.player_spd_x^2 + self.player_spd_y^2) ^ 0.5
    if mag > self.speed_max then
        self.player_spd_x = (self.player_spd_x / mag) * self.speed_max
        self.player_spd_y = (self.player_spd_y / mag) * self.speed_max
    end
    if self.player_pos_y < 0 then
        self.player_pos_y = self.VH
    end
    if self.player_pos_x < 0 then
        self.player_pos_x = self.VW
    end
    if self.player_pos_y > self.VH then
        self.player_pos_y = 0
    end
    if self.player_pos_x > self.VW then
        self.player_pos_x = 0
    end
    -- player teleport
    if (std.key.press.down or std.key.press.c) and std.milis > self.player_last_teleport + 1000 then
        self.player_last_teleport = std.milis
        self.laser_pos_x1 = self.player_pos_x
        self.laser_pos_y1 = self.player_pos_y 
        self.player_spd_x = 0
        self.player_spd_y = 0
        repeat
            self.player_pos_x = std.math.random(1, self.VW)
            self.player_pos_y = std.math.random(1, self.VH)
        until not asteroid_nest(self, std, self.player_pos_x, self.player_pos_y, -1)
    end
    -- player shoot
    if not self.laser_enabled and self.state == 4 and std.key.press.a then
        local index = 1
        local asteroids = #self.asteroid_size
        local sin = std.math.cos(self.player_angle - std.math.pi/2)
        local cos = std.math.sin(self.player_angle - std.math.pi/2)
        local laser_fake_x = self.player_pos_x - (self.laser_distance_fire * sin)
        local laser_fake_y = self.player_pos_y - (self.laser_distance_fire * cos)
        self.laser_pos_x2 = self.player_pos_x + (self.laser_distance_fire * sin)
        self.laser_pos_y2 = self.player_pos_y + (self.laser_distance_fire * cos)
        self.laser_pos_x1 = self.player_pos_x + (12 * sin)
        self.laser_pos_y1 = self.player_pos_y + (12 * cos)
        self.laser_last_fire = std.milis
        self.laser_enabled = true
        while index <= asteroids do
            if self.asteroid_size[index] ~= -1 then
                local size = self.asteroid_size[index]/2
                local x = self.asteroid_pos_x[index] + size
                local y = self.asteroid_pos_y[index] + size
                local dis_p1 = std.math.dis(self.laser_pos_x1, self.laser_pos_y1, x,y)
                local dis_p2 = std.math.dis(self.laser_pos_x2, self.laser_pos_y2, x,y)
                local dis_fake = std.math.dis(laser_fake_x, laser_fake_y, x,y)
                local intersect = intersect_line_circle(self.laser_pos_x1, self.laser_pos_y1, self.laser_pos_x2, self.laser_pos_y2, x, y, size*2)
                if intersect and dis_p2 < dis_fake and dis_p1 < self.laser_distance_fire then
                    self.score = self.score + asteroid_destroy(self, std, index)
                end
            end
            index = index + 1
        end
    end
    if self.laser_enabled and std.milis > self.laser_last_fire + self.laser_time_recharge then
        self.laser_enabled = false
    end
    -- player death
    if self.imortal ~= 1 and self.state == 4 and asteroid_nest(self, std, self.player_pos_x, self.player_pos_y, -1) then
        self.menu_time = std.milis
        self.lifes = self.lifes - 1
        self.state = 5
    end
    -- asteroids move
    local index = 1
    self.asteroids_count = 0
    while index <= #self.asteroid_size do
        if self.asteroid_size[index] ~= -1 then
            self.asteroids_count = self.asteroids_count + 1
            self.asteroid_pos_x[index] = self.asteroid_pos_x[index] + self.asteroid_spd_x[index]
            self.asteroid_pos_y[index] = self.asteroid_pos_y[index] + self.asteroid_spd_y[index]
            if self.asteroid_pos_y[index] < -self.asteroid_size[index] then
                self.asteroid_pos_y[index] = self.VH
            end
            if self.asteroid_pos_x[index] < -self.asteroid_size[index] then
                self.asteroid_pos_x[index] = self.VW
            end
            if self.asteroid_pos_y[index] > self.VH then
                self.asteroid_pos_y[index] = 0
            end
            if self.asteroid_pos_x[index] > self.VW then
                self.asteroid_pos_x[index] = 0
            end
        end
        index = index + 1
    end
    -- next level
    if self.state == 4 and self.asteroids_count == 0 then
        self.menu_time = std.milis
        self.state = 6
    end
    if self.state == 6 and std.milis > self.menu_time + 3000 then
        std.app.reset()
        self.level = self.level + 1
        self.state = 4
    end
    -- restart 
    if self.state == 5 and std.milis > self.menu_time + 3000 then
        std.app.reset()
        self.state = 4
        if self.lifes == 0 then
            self.score = 0
            self.lifes = 3
            self.level = 1
        end
    end
end

local function draw(self, std)
    local death_anim = self.state == 5 and std.milis < self.menu_time + 50 
    std.draw.clear(death_anim and std.color.white or std.color.black)
    
    if self.state == 1 then
        local h = self.VH/24
        local hmenu = (self.menu*h) + (h*11) - (h/3)
        local language = std.i18n.get_language()
        local graphics = self.graphics_fastest == 1 and 'fast' or 'pretty'
        local s = std.math.min(self.width/4, draw_logo(self, std, h*4))
        local w1, w2 = (self.width/2 - s), (self.width/2 + s)
        std.text.font_size(h/2)
        std.draw.color(std.color.white)
        if self.player_pos_x ~= (self.width/2) then
            std.text.print(self.width/2 - s, h*11, 'Continue')
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
        std.text.print_ex(w2, h*13, self.level, -1)
        std.text.print_ex(w2, h*14, self.imortal, -1)
        std.text.print_ex(w2, h*15, self.asteroids_max, -1)
        std.text.print_ex(w2, h*16, graphics, -1)
        std.text.print_ex(w2, h*17, language, -1)
        return
    elseif self.state == 2 then
        local height = self.height/4
        local anim = std.math.cos(std.milis/100) * 5
        draw_logo(self, std, height, anim) 
        std.text.font_size(16)
        std.draw.color(std.color.white)
        std.text.print_ex(self.width/2 + anim, height*2, 'Rodrigo Dornelles', 0)
        return
    end
    -- draw asteroids
    std.draw.color(std.color.white)
    local index = 1
    while index <= #self.asteroid_size do
        if self.asteroid_size[index] ~= -1 then
            local ax, ay = v2s(self, self.asteroid_pos_x[index], self.asteroid_pos_y[index])
            if self.graphics_fastest == 1 then
                local s = v2s_size(self, self.asteroid_size[index])
                std.draw.rect(1, ax, ay, s, s)
            elseif self.asteroid_size[index] == self.asteroid_large_size then
                std.draw.poly(1, self.asteroid_large, ax, ay)
            elseif self.asteroid_size[index] == self.asteroid_mid_size then
                std.draw.poly(1, self.asteroid_mid, ax, ay)
            elseif self.asteroid_size[index] == self.asteroid_small_size then
                std.draw.poly(1, self.asteroid_small, ax, ay)
            else
                std.draw.poly(1, self.asteroid_mini, ax, ay)
            end
        end
        index = index + 1
    end

    -- draw player
    if self.state ~= 5 then
        local px, py = v2s(self, self.player_pos_x, self.player_pos_y)
        -- triangle
        std.draw.color(std.color.yellow)
        std.draw.poly(2, self.spaceship, px, py, v2s_size(self, self.player_size), self.player_angle)
        
        -- laser bean
        if self.laser_enabled and std.milis < self.laser_last_fire + self.laser_time_fire then
            std.draw.color(std.color.green)
            local lx1, ly1 = v2s(self, self.laser_pos_x1, self.laser_pos_y1)
            local lx2, ly2 = v2s(self, self.laser_pos_x2, self.laser_pos_y2)
            std.draw.line(lx1, ly1, lx2, ly2)
        end
        
        std.draw.color(std.color.red)
        -- boost
        if std.key.press.up or std.key.press.b  then
            local s = std.math.random(4, 12)
            local sin = std.math.cos(self.player_angle - std.math.pi/2)
            local cos = std.math.sin(self.player_angle - std.math.pi/2)
            local vx = self.player_pos_x - (sin * (s + 12)) - (s/2)
            local vy = self.player_pos_y - (cos * (s + 12)) - (s/2)
            local bx, by = v2s(self, vx, vy)
            local bs = v2s_size(self, s)
            std.draw.rect(1, bx, by, bs, bs)
        end
        -- teleport
        if std.milis < self.player_last_teleport + 100 then
            local lx1, ly1 = v2s(self, self.laser_pos_x1, self.laser_pos_y1)
            std.draw.line(lx1, ly1, px, py)
        end
    end

    -- draw gui bars
    std.draw.color(std.color.black)
    local _, game_top_y = v2s(self, 0, 0)
    std.draw.rect(0, 0, 0, self.width, game_top_y)
    local _, game_bottom_y = v2s(self, 0, self.VH)
    std.draw.rect(0, 0, game_bottom_y, self.width, self.height - game_bottom_y)
    
    std.draw.color(std.color.white)
    std.text.font_size(v2s_size(self, self.width/40))

    local pw, ph = 10, 2
    local hf = std.app.height - ph
    local wf = std.app.width - pw
    local wc = std.app.width / 2

    std.text.print_ex(pw, ph, 'lifes: '..tostring(self.lifes), 1)
    std.text.print_ex(wc, ph, 'asteroids: '..tostring(self.asteroids_count), 0)
    std.text.print_ex(wf, ph, 'level: '..tostring(self.level), -1)    
    std.text.print_ex(pw, hf, 'score: '..tostring(self.score), 1, -1)
    std.text.print_ex(wf, hf, 'highscore: '..tostring(self.highscore), -1, -1)
end

local function exit(self, std)
    self.highscore = std.math.max(self.score, self.highscore)
    self.asteroid_pos_x = nil
    self.asteroid_pos_y = nil
    self.asteroid_spd_x = nil
    self.asteroid_spd_y = nil
    self.asteroid_size = nil
    self.asteroid_large = nil
    self.asteroid_mid =  nil
    self.asteroid_small = nil
    self.asteroid_mini = nil
end

local P = {
    meta={
        id='com.glyengine.asteroids',
        title='AsteroidsTV',
        author='RodrigoDornelles',
        description='similar to the original but with lasers because televisions may have limited hardware.',
        tizen_package='3202411037732',
        version='2.0.0'
    },
    config = {
        require = 'math math.random i18n?'
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
