--! @par Game FSM
--! @startuml
--! hide empty description
--! state 1 as "menu"
--! state 2 as "game_play"
--! state 3 as "game_over"
--! 
--! [*] -> 2
--! 1 --> 2
--! 1 --> 3
--! 2 --> 1
--! 3 --> 2
--! @enduml

local function check_collision(self, std, bird_x, bird_y, pipe_x, pipe_y, pipe_gap)
    local bird_size = 20  -- Bird size
    local pipe_width = 50  -- Pipe width
    local pipe_height = self.height  -- Full pipe height
    
    -- Check horizontal collision
    if bird_x + bird_size > pipe_x and bird_x < pipe_x + pipe_width then
        -- Check vertical collision with top pipe
        if bird_y < pipe_y or 
           -- Check vertical collision with bottom pipe
           bird_y + bird_size > pipe_y + pipe_gap then
            return true
        end
    end
    
    return false
end

local function init(self, std)
    -- Reset game state completely
    self.state = 2  -- Start directly in playing state
    self.score = 0
    
    -- Bird properties
    self.bird_y = self.height / 2
    self.bird_velocity = 0
    self.bird_gravity = 0.5
    self.bird_jump_strength = -7
    
    -- Pipe properties
    self.pipes = {}
    self.pipe_gap = 200  -- Gap between top and bottom pipes
    self.pipe_width = 50
    self.pipe_spawn_timer = 0
    self.pipe_spawn_interval = 1500  -- milliseconds between pipe spawns
    
    -- Menu
    self.menu = 2
    self.menu_time = 0

    
end

local function spawn_pipe(self, std)
    local pipe_height = (std.milis % (self.height - self.pipe_gap - 200)) + 100
    table.insert(self.pipes, {
        x = self.width,
        y = pipe_height,
        passed = false
    })
end

local function loop(self, std)
    if self.state == 1 then
        -- Menu navigation
        local keyh = std.key.axis.x + std.key.axis.a 
        if std.key.axis.y ~= 0 and std.milis > self.menu_time + 250 then
            self.menu = ((self.menu + std.key.axis.y - 2) % 3) + 2
            self.menu_time = std.milis
        end
        
        if keyh ~= 0 and std.milis > self.menu_time + 100 then
            self.menu_time = std.milis
            if self.menu == 2 then
                init(self, std)  -- reset stats
            elseif self.menu == 3 then
                -- nothing for now
            elseif self.menu == 4 then
                std.app.exit()
            end
        end
        return
    end
    
    if self.state == 2 then
        -- Bird physics
        self.bird_velocity = self.bird_velocity + self.bird_gravity
        self.bird_y = self.bird_y + self.bird_velocity
        
        -- Jump mechanic
        if std.key.press.a then
            self.bird_velocity = self.bird_jump_strength
        end
        
        -- Spawn pipes
        self.pipe_spawn_timer = self.pipe_spawn_timer + std.delta
        if self.pipe_spawn_timer >= self.pipe_spawn_interval then
            spawn_pipe(self, std)
            self.pipe_spawn_timer = 0
        end
        
        -- Move pipes
        for i = #self.pipes, 1, -1 do
            self.pipes[i].x = self.pipes[i].x - 3
            
            -- Check scoring
            if not self.pipes[i].passed and self.pipes[i].x < self.width/2 then
                self.score = self.score + 1
                self.pipes[i].passed = true
            end
            
            -- Remove off-screen pipes
            if self.pipes[i].x < -self.pipe_width then
                table.remove(self.pipes, i)
            end
            
            -- Collision detection
            if check_collision(self, std, self.width/4, self.bird_y, 
                               self.pipes[i].x, self.pipes[i].y, self.pipe_gap) then
                self.state = 3  -- Game over
                self.menu_time = std.milis
            end
        end
        
        -- botton and top collision
        if self.bird_y > self.height - 20 or self.bird_y < 0 then
            self.state = 3  -- Game over
            self.menu_time = std.milis
        end
    end
    
    -- Game over state
    if self.state == 3 and std.milis > self.menu_time + 2000 then
        self.state = 1
        self.highscore = (self.highscore and self.highscore < self.score)  and self.score or self.highscore
    end
end

local function draw(self, std)
    std.draw.clear(std.color.skyblue)
    
    if self.state == 1 then
        std.draw.color(std.color.yellow)
        std.text.put(40, std.app.width <= 240 and 6 or 3, 'Bird', 4)
        std.text.put(20, 8 + self.menu, 'X')

        std.draw.color(std.color.white)
        std.text.put(30, 3, 'Capy', 4)
        std.text.put(1, 10, 'New Game')
        std.text.put(1, 11, 'Settings')
        std.text.put(1, 12, 'Exit')
        std.text.put(1, 16, 'High Score: ' .. (self.highscore or 0), 2)
        return
    end
    
    if self.state == 2 or self.state == 3 then
        -- Draw pipes
        std.draw.color(std.color.green)
        for _, pipe in ipairs(self.pipes) do
            -- Top pipe
            std.draw.rect(0, pipe.x, 0, self.pipe_width, pipe.y)
            -- Bottom pipe
            std.draw.rect(0, pipe.x, pipe.y + self.pipe_gap, self.pipe_width, self.height - pipe.y - self.pipe_gap)
        end
        
        -- Draw bird
        std.draw.color(std.color.beige)
        std.draw.rect(0, self.width/4, self.bird_y, 20, 20)
        std.draw.color(std.color.darkbrown)
        std.draw.rect(1, self.width/4, self.bird_y, 20, 20)
        
        -- Score display
        std.draw.color(std.color.yellow)
        std.text.put(60, 1, 'Score: ' .. self.score)
    end
    
    -- Game over screen
    if self.state == 3 then
        std.draw.color(std.color.black)
        std.text.put(26, 8, 'Game Over', 5)
    end
end

local function exit(self, std)
    self.pipes = nil
end

local P = {
    meta={
        title='CapyBird',
        author='Alex Oliveira',
        description='A simple Flappy Bird clone',
        version='1.0.0'
    },
    config = {
        require = 'math math.random',
    },
    callbacks={
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P
