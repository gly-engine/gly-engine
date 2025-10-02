--! @par Reference
--! @details
--! This demo shows the engine's ability to create a pseudo 3D raycast,
--! inspired by Microsoft's screensaver.
--! @lihttps://en.wikipedia.org/wiki/3D_Maze
--!

local function wolf_getmap(self, std, x, y)
    local mapX = std.math.floor(x)
    local mapY = std.math.floor(y)
    if mapX < 1 or mapX > self.map.width or mapY < 1 or mapY > self.map.height then
        return 1
    end
    return self.map.grid[(mapY - 1) * self.map.width + mapX]
end

local function wolf_raycast(self, std, angle)
    local dist = 0
    local hit = false
    local hitX, hitY, hitType = nil, nil, 0
    local cosA = std.math.cos(angle)
    local sinA = std.math.sin(angle)
    while (not hit) and (dist < self.max_distance) do
        dist = dist + self.ray_step
        local x = self.player.x + cosA * dist
        local y = self.player.y + sinA * dist
        local cellType = wolf_getmap(self, std, x, y)
        if cellType ~= 0 then
            hit = true
            hitX, hitY = x, y
            hitType = cellType
        end
    end
    return dist, hitX, hitY, hitType
end

local function wolf_newmap(std)
    local mapWidth, mapHeight = 20, 20
    local grid = {}
    for y = 1, mapHeight do
        for x = 1, mapWidth do
            grid[(y-1)*mapWidth+x] = (x==1 or x==mapWidth or y==1 or y==mapHeight) and 1 or (math.random()<0.2 and 1 or 0)
        end
    end
    grid[(3-1)*mapWidth+3] = 0
    local finalY = std.math.floor(mapHeight/2)
    grid[(finalY-1)*mapWidth+mapWidth] = 2

    return {width=mapWidth, height=mapHeight, grid=grid}
end

local function bot_bfs(self, std, startX, startY, goalX, goalY)
    local queue = {}
    local visited = {}
    local parent = {}
    local dirs = {{dx=1, dy=0}, {dx=-1, dy=0}, {dx=0, dy=1}, {dx=0, dy=-1}}

    queue[#queue+1] = {x=startX, y=startY}
    visited[(startY-1)*self.map.width + startX] = true

    while #queue > 0 do
        local current = table.remove(queue, 1)
        for _, dir in ipairs(dirs) do
            local nx = current.x + dir.dx
            local ny = current.y + dir.dy
            if nx >= 1 and nx <= self.map.width and ny >= 1 and ny <= self.map.height then
                local idx = (ny-1)*self.map.width + nx
                if not visited[idx] and (wolf_getmap(self, std, nx, ny) == 0 or wolf_getmap(self, std, nx, ny) == 2) then
                    visited[idx] = true
                    parent[idx] = current
                    queue[#queue+1] = {x=nx, y=ny}
                    if nx == goalX and ny == goalY then
                        local path = {}
                        local node = {x=nx, y=ny}
                        while node do
                            table.insert(path, 1, node)
                            local p = parent[(node.y-1)*self.map.width + node.x]
                            node = p
                        end
                        return path
                    end
                end
            end
        end
    end
    return nil
end

local function init(self, std)
    self.player = {x=3, y=3, angle=0, fov=std.math.pi/3, speed=5, turn_speed=1.5}
    self.bot = {timer=0, angle=self.player.angle, path=nil, targetIndex=1, state="turning"}
    self.map = wolf_newmap(std) 
    self.num_rays = 100
    self.max_distance = 30
    self.ray_step = 0.1
    self.ray_angle_step = self.player.fov / self.num_rays
end

local function bot_move(self, std, dt)
    local goalX, goalY = self.map.width, std.math.floor(self.map.height/2)
    local currentCell = {x=std.math.floor(self.player.x), y=std.math.floor(self.player.y)}

    if currentCell.x == goalX and currentCell.y == goalY then return end

    if not self.bot.path then
        self.bot.path = bot_bfs(self, std, currentCell.x, currentCell.y, goalX, goalY)
        self.bot.targetIndex = 2
        self.bot.state = "turning"
    end

    if not self.bot.path or #self.bot.path < self.bot.targetIndex then return end

    local targetCell = self.bot.path[self.bot.targetIndex]
    if currentCell.x == targetCell.x and currentCell.y == targetCell.y then
        self.bot.targetIndex = self.bot.targetIndex + 1
        self.bot.state = "turning"
        return
    end

    local dx = targetCell.x - currentCell.x
    local dy = targetCell.y - currentCell.y
    local targetAngle = (dx == 1 and 0) or (dx == -1 and std.math.pi) or (dy == 1 and std.math.pi/2) or 3*std.math.pi/2

    self.bot.angle = targetAngle
    local angleDiff = std.math.abs(self.player.angle - targetAngle)
    angleDiff = (angleDiff + std.math.pi) % (2 * std.math.pi) - std.math.pi
    
    if std.math.abs(angleDiff) < 0.1 then
        self.player.x = self.player.x + std.math.cos(self.player.angle) * self.player.speed * dt
        self.player.y = self.player.y + std.math.sin(self.player.angle) * self.player.speed * dt
    end
end

local function loop(self, std)
    self.bot.timer = self.bot.timer + std.delta
    if std.key.press.any then
        self.bot.timer = 0
        self.bot.path = nil
    end

    if self.bot.timer >= 3000 then
        local dt = std.delta / 1000
        local angleDiff = self.bot.angle - self.player.angle
        if std.math.abs(angleDiff) > self.player.turn_speed * dt then
            self.player.angle = self.player.angle + (angleDiff > 0 and self.player.turn_speed or -self.player.turn_speed) * dt
        else
            self.player.angle = self.bot.angle
        end

        bot_move(self, std, dt)
        local cellX, cellY = std.math.floor(self.player.x), std.math.floor(self.player.y)
        if wolf_getmap(self, std, cellX, cellY) == 2 then std.app.reset() end
        return
    end

    local dt = std.delta / 1000
    local speed = self.player.speed * dt
    local new_x = self.player.x + (std.key.press.up and std.math.cos(self.player.angle) or std.key.press.down and -std.math.cos(self.player.angle) or 0) * speed
    local new_y = self.player.y + (std.key.press.up and std.math.sin(self.player.angle) or std.key.press.down and -std.math.sin(self.player.angle) or 0) * speed

    if wolf_getmap(self, std, new_x, self.player.y) == 0 then self.player.x = new_x end
    if wolf_getmap(self, std, self.player.x, new_y) == 0 then self.player.y = new_y end

    if wolf_getmap(self, std, new_x, self.player.y) == 2 or wolf_getmap(self, std, self.player.x, new_y) == 2 then
        std.app.reset()
    end

    if std.key.press.left then self.player.angle = self.player.angle - self.player.turn_speed * dt end
    if std.key.press.right then self.player.angle = self.player.angle + self.player.turn_speed * dt end
end

local function draw(self, std)
    std.draw.clear(0xFFFFFFFF)
    std.draw.color(0xFFA500FF)
    std.draw.rect(0, 0, self.height/2, self.width, self.height/2)

    for i = 0, self.num_rays do
        local angle = self.player.angle - self.player.fov/2 + (i * self.ray_angle_step)
        local dist, _, _, hitType = wolf_raycast(self, std, angle)
        local lineHeight = std.math.min(self.height, 1000 / (dist + 0.0001))
        local x = (i / self.num_rays) * self.width

        local wallColor = hitType == 2 and 0x0000FFFF or (std.math.floor(std.math.max(0.2, 1 - dist/self.max_distance)*255)*0x1000000+0xFF)
        std.draw.color(wallColor)
        std.draw.rect(0, x, (self.height - lineHeight)/2, self.width/self.num_rays + 1, lineHeight)
    end
end

local P = {
    meta = {
        title = 'Maze3D',
        author = 'RodrigoDornelles and AlexOliveira',
        description = 'Raycasting com BFS pathfinding',
        version = '1.0.0'
    },
    config = {
        require = 'math math.random'
    },
    callbacks = {
        init = init,
        loop = loop,
        draw = draw
    }
}

return P
