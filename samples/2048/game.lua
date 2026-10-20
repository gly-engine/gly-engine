local SIZE = 4
local SLIDE_DUR = 100

local COLORS = {
    bg = 0xF3E8FFFF, board_bg = 0xE0C8F0FF, empty_cell = 0xEDD5F5FF,
    text_light = 0xFFFFFFFF, text_dark = 0x5B2A6EFF,
    accent = 0xF472B6FF, gold = 0xF9A8D4FF,
    [0]=0xEDD5F5FF, [2]=0xFFF0F5FF, [4]=0xFCE4ECFF, [8]=0xF8BBD0FF,
    [16]=0xF48FB1FF, [32]=0xF06292FF, [64]=0xEC407AFF, [128]=0xD1A3FFFF,
    [256]=0xB388FFFF, [512]=0x9C7CFFFF, [1024]=0x7E57C2FF, [2048]=0xFFD700FF,
}

local POP = {merge_dur=220, spawn_dur=250, merge_s=1.25, spawn_s=1.15}

local function popScale(el, dur, ms)
    if el >= dur then return 1.0 end
    return 1.0 + (ms - 1.0) * math.sin(el / dur * math.pi)
end

local function newBoard()
    local b = {}
    for y = 1, SIZE do b[y] = {0,0,0,0} end
    return b
end

local function eachCell(fn)
    for y = 1, SIZE do for x = 1, SIZE do fn(y, x) end end
end

local function spawn(self)
    local e = {}
    eachCell(function(y, x) if self.board[y][x] == 0 then e[#e+1] = {y, x} end end)
    if #e == 0 then return end
    local p = e[math.random(#e)]
    self.board[p[1]][p[2]] = math.random() < 0.1 and 4 or 2
    self.new_tile = {y=p[1], x=p[2]}
end

local function cloneBoard(b)
    local c = {}
    for y = 1, SIZE do c[y] = {b[y][1], b[y][2], b[y][3], b[y][4]} end
    return c
end

local function boardsEqual(a, b)
    for y = 1, SIZE do for x = 1, SIZE do
        if a[y][x] ~= b[y][x] then return false end
    end end
    return true
end

local function canMove(b)
    for y = 1, SIZE do for x = 1, SIZE do
        if b[y][x] == 0 then return true end
        if x < SIZE and b[y][x] == b[y][x+1] then return true end
        if y < SIZE and b[y][x] == b[y+1][x] then return true end
    end end
    return false
end

local function hasVal(b, v)
    for y = 1, SIZE do for x = 1, SIZE do
        if b[y][x] == v then return true end
    end end
    return false
end

local function rev(r) return {r[4], r[3], r[2], r[1]} end
local function getCol(b, x) return {b[1][x], b[2][x], b[3][x], b[4][x]} end
local function setCol(b, x, c) for y = 1, SIZE do b[y][x] = c[y] end end

local function processRow(row, self)
    local nz = {}
    for i = 1, SIZE do if row[i] ~= 0 then nz[#nz+1] = {o=i, v=row[i]} end end
    local res, mv, mg = {}, {}, {}
    local k, d = 1, 1
    while k <= #nz do
        if k < #nz and nz[k].v == nz[k+1].v then
            local val = nz[k].v * 2
            res[d] = val
            mv[#mv+1] = {f=nz[k].o, t=d, v=nz[k].v}
            mv[#mv+1] = {f=nz[k+1].o, t=d, v=nz[k+1].v}
            mg[d] = true
            self.score = self.score + val
            if self.score > self.highscore then self.highscore = self.score end
            k = k + 2
        else
            res[d] = nz[k].v
            mv[#mv+1] = {f=nz[k].o, t=d, v=nz[k].v}
            k = k + 1
        end
        d = d + 1
    end
    while d <= SIZE do res[d] = 0; d = d + 1 end
    return res, mv, mg
end

local function doDir(self, vert, flip)
    local R = SIZE + 1
    for i = 1, SIZE do
        local line = vert and getCol(self.board, i) or self.board[i]
        if flip then line = rev(line) end
        local res, moves, merges = processRow(line, self)
        if flip then res = rev(res) end
        if vert then setCol(self.board, i, res) else self.board[i] = res end
        for _, m in ipairs(moves) do
            local ff, ft = flip and R-m.f or m.f, flip and R-m.t or m.t
            local fy, fx, ty, tx
            if vert then fy,fx,ty,tx = ff,i,ft,i else fy,fx,ty,tx = i,ff,i,ft end
            self.anims[#self.anims+1] = {fy=fy, fx=fx, ty=ty, tx=tx, v=m.v}
        end
        for d in pairs(merges) do
            local dd = flip and R-d or d
            self.merged[#self.merged+1] = vert and {y=dd, x=i} or {y=i, x=dd}
        end
    end
end

local DIRS = {
    left  = function(s) doDir(s, false, false) end,
    right = function(s) doDir(s, false, true) end,
    up    = function(s) doDir(s, true, false) end,
    down  = function(s) doDir(s, true, true) end,
}

local function resetGame(self)
    self.board = newBoard()
    self.score = 0; self.state = "playing"; self.moves = 0
    self.new_tile = nil; self.slide_t = 0; self.pop_t = 0; self.spawn_t = 0
    self.merged = {}; self.anims = {}
    spawn(self); spawn(self)
end

local function init(self)
    math.randomseed(os.time())
    self.highscore = self.highscore or 0
    self.anim_time = 0; self.continue = false
    self.last_move = 0; self.move_delay = 150
    resetGame(self)
end

local function loop(self, std)
    self.anim_time = std.milis
    local k = std.key.press

    if self.state == "win" and not self.continue then
        if k.a or k.enter then self.continue = true; self.state = "playing"
        elseif k.b or k.d then resetGame(self) end
        return
    end
    if self.state == "lose" then
        if k.a or k.enter or k.b then resetGame(self) end
        return
    end
    if std.milis < self.last_move + self.move_delay then return end

    local dir = (k.left and "left") or (k.right and "right") or (k.up and "up") or (k.down and "down")
    if not dir then return end

    local before = cloneBoard(self.board)
    self.merged = {}; self.anims = {}
    DIRS[dir](self)

    if not boardsEqual(before, self.board) then
        self.slide_t = std.milis
        self.pop_t = std.milis + SLIDE_DUR
        self.spawn_t = std.milis + SLIDE_DUR
        self.last_move = std.milis
        self.moves = self.moves + 1
        spawn(self)
        if not self.continue and hasVal(self.board, 2048) then
            self.state = "win"; return
        end
    else
        self.merged = {}; self.anims = {}
    end
    if not canMove(self.board) then self.state = "lose" end
end

local function isMerged(list, ty, tx)
    for _, m in ipairs(list) do if m.y == ty and m.x == tx then return true end end
    return false
end

local function drawTile(std, px, py, s, cr, val, sc)
    sc = sc or 1.0
    local ss = s * sc
    local off = (ss - s) / 2
    local rx, ry = px - off, py - off
    std.draw.color(COLORS[val] or COLORS[2048])
    std.draw.rect2(0, rx, ry, ss, ss, cr * sc)
    -- centralizar numero 
    if val > 0 then
        std.draw.color(val <= 4 and COLORS.text_dark or COLORS.text_light)
        local d = #tostring(val)
        local fs = std.math.max(ss * (d <= 2 and 0.45 or d == 3 and 0.38 or 0.32), 16)
        std.text.font_size(fs)
        local cx = rx + ss / 2
        local cy = ry + (ss - fs) / 2
        std.text.print_ex(cx, cy, tostring(val), 0)
    end
end

local function draw(self, std)
    std.draw.clear(COLORS.bg)
    local bs = std.math.min(self.width, self.height) * 0.58
    local cs = bs / SIZE
    local gap = cs * 0.08
    local ts = cs - gap * 2
    local cr = ts * 0.12
    local sx = (self.width - bs) / 2
    local sy = (self.height - bs) / 2 + self.height * 0.08

    -- Header
    local hy = sy - self.height * 0.15
    std.draw.color(COLORS.accent)
    std.text.font_size(bs * 0.085)
    std.text.print_ex(self.width / 2, hy, "2048", 0)

    -- Score boxes
    local scy = hy + bs * 0.09
    local bw, bh, bg = bs * 0.28, bs * 0.11, bs * 0.03
    for _, sb in ipairs({{self.width/2 - bw - bg/2, "SCORE", self.score},
                         {self.width/2 + bg/2, "BEST", self.highscore}}) do
        std.draw.color(COLORS.board_bg)
        std.draw.rect2(0, sb[1], scy, bw, bh, 8)
        std.draw.color(COLORS.text_dark)
        std.text.font_size(12)
        std.text.print_ex(sb[1] + bw/2, scy + bh * 0.25, sb[2], 0)
        std.draw.color(COLORS.accent)
        std.text.font_size(20)
        std.text.print_ex(sb[1] + bw/2, scy + bh * 0.65, tostring(sb[3]), 0)
    end

    -- Board background
    std.draw.color(COLORS.board_bg)
    std.draw.rect2(0, sx - gap, sy - gap, bs + gap*2, bs + gap*2, cr*2)

    -- Empty cells (always drawn as base layer)
    eachCell(function(y, x)
        std.draw.color(COLORS.empty_cell)
        std.draw.rect2(0, sx + (x-1)*cs + gap, sy + (y-1)*cs + gap, ts, ts, cr)
    end)

    -- Slide or static tiles
    local sl_el = self.anim_time - (self.slide_t or 0)
    local sliding = sl_el < SLIDE_DUR and #self.anims > 0

    if sliding then
        local t = sl_el / SLIDE_DUR
        t = 1 - (1-t)*(1-t)
        for _, a in ipairs(self.anims) do
            local fpx = sx + (a.fx-1)*cs + gap
            local fpy = sy + (a.fy-1)*cs + gap
            local tpx = sx + (a.tx-1)*cs + gap
            local tpy = sy + (a.ty-1)*cs + gap
            drawTile(std, fpx + (tpx-fpx)*t, fpy + (tpy-fpy)*t, ts, cr, a.v)
        end
    else
        local pop_el = self.anim_time - (self.pop_t or 0)
        local spn_el = self.anim_time - (self.spawn_t or 0)
        eachCell(function(y, x)
            local v = self.board[y][x]
            if v == 0 then return end
            local px = sx + (x-1)*cs + gap
            local py = sy + (y-1)*cs + gap
            local sc = 1.0
            if isMerged(self.merged, y, x) then
                sc = popScale(pop_el, POP.merge_dur, POP.merge_s)
            elseif self.new_tile and self.new_tile.y == y and self.new_tile.x == x
                   and spn_el >= 0 and spn_el < POP.spawn_dur then
                local st = spn_el / POP.spawn_dur
                sc = math.max(0.3 + 0.7*st + (POP.spawn_s - 1.0) * math.sin(st * math.pi), 0.3)
            end
            drawTile(std, px, py, ts, cr, v, sc)
        end)
    end

    -- Footer
    local fy = sy + bs + self.height * 0.03
    std.draw.color(COLORS.text_dark)
    std.text.font_size(std.math.max(self.height * 0.025, 14))
    if self.state == "playing" then
        std.text.print_ex(self.width/2, fy, "Use as SETAS para mover", 0)
        std.text.print_ex(self.width/2, fy + self.height*0.035, "Movimentos: "..self.moves, 0)
        return
    end

    -- Overlay
    std.draw.color(0x5B2A6E99)
    std.draw.rect(0, 0, 0, self.width, self.height)
    local cy = self.height / 2
    if self.state == "win" then
        std.draw.color(COLORS.gold)
        std.text.font_size(std.math.max(self.height/8, 48))
        std.text.print_ex(self.width/2, cy - self.height*0.1, "VOCE VENCEU!", 0)
        std.draw.color(COLORS.text_light)
        std.text.font_size(std.math.max(self.height/20, 20))
        std.text.print_ex(self.width/2, cy + self.height*0.02, "Score: "..self.score, 0)
    else
        std.draw.color(COLORS.accent)
        std.text.font_size(std.math.max(self.height/8, 48))
        std.text.print_ex(self.width/2, cy - self.height*0.12, "GAME OVER", 0)
        std.draw.color(COLORS.text_light)
        std.text.font_size(std.math.max(self.height/20, 20))
        std.text.print_ex(self.width/2, cy, "Score: "..self.score, 0)
        std.text.font_size(std.math.max(self.height/25, 16))
        std.text.print_ex(self.width/2, cy + self.height*0.12, "[Enter] Jogar Novamente", 0)
    end
end

return {
    meta = {
        title='2048 TV Edition',
        author='Miza',
        version='1.3.0'
    },
    
    callbacks = {
        init=init,
        loop=loop,
        draw=draw}
}