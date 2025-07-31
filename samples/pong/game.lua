--! @par Reference
--! @details
--! This Pong game is inspired by "Paredao" a game from the first-generation
--! Brazilian console Philco-Ford Telejogo. (1977)
--! @li https://www.vgdb.com.br/telejogo/jogos/paredao
--!

local function init(self, std)
    self.highscore = self.highscore or 0
    self.player_pos = self.height/2
    self.ball_pos_x = self.width/2
    self.ball_pos_y = self.height/2
    self.ball_spd_x = 50
    self.ball_spd_y = 30
    self.score = 0
end

local function loop(self, std)
    -- moves
    self.ball_size = std.math.max(self.width, self.height) / 160
    self.player_size = (std.math.min(self.width, self.height) / 8) + 2
    self.ball_pos_x = std.math.clamp(self.ball_pos_x + (self.width * self.ball_spd_x * std.delta)/100000, 0, self.width)
    self.ball_pos_y = std.math.clamp(self.ball_pos_y + (self.height * self.ball_spd_y * std.delta)/100000, 0, self.height)
    self.player_pos = std.math.clamp(self.player_pos + (std.key.axis.y * self.ball_size), 0, self.height - self.player_size)  

    -- colisions
    if self.ball_pos_x >= (self.width - self.ball_size) then
        self.ball_spd_x = -std.math.abs(self.ball_spd_x)
    end
    if self.ball_pos_y >= (self.height - self.ball_size) then
        self.ball_spd_y = -std.math.abs(self.ball_spd_y)
    end
    if self.ball_pos_y <= 0 then
        self.ball_spd_y = std.math.abs(self.ball_spd_y)
    end
    if self.ball_pos_x <= 0 then 
        if std.math.clamp(self.ball_pos_y, self.player_pos, self.player_pos + self.player_size) == self.ball_pos_y then
            self.ball_spd_y = self.ball_spd_y + self.ball_spd_x - (std.milis % (self.ball_spd_x*2))
            self.ball_spd_x = std.math.abs(self.ball_spd_x + (self.ball_spd_x/10))
            self.score = self.score + 1
        else
            std.app.reset()
        end
    end
end

local function draw(self, std)
    std.draw.clear(std.color.black)
    std.draw.color(std.color.white)
    std.draw.rect(0, self.ball_size, self.player_pos, self.ball_size, self.player_size)
    std.draw.rect(0, self.ball_pos_x, self.ball_pos_y, self.ball_size, self.ball_size)
    std.text.put(20, 1, self.score)
    std.text.put(60, 1, self.highscore)
end

local function exit(self, std)
    self.highscore = std.math.max(self.highscore, self.score)
end

local P = {
    meta={
        title='Ping Pong',
        author='RodrigoDornelles',
        description='simple pong',
        version='1.0.0'
    },
    callbacks={
        init=init,
        loop=loop,
        draw=draw,
        exit=exit
    }
}

return P;
