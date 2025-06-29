local function install(std)
    std.color = std.color or {}
    std.color.white = 7
    std.color.lightgray = 6
    std.color.gray = 5
    std.color.darkgray = 5
    std.color.yellow = 10
    std.color.gold = 9
    std.color.orange = 9
    std.color.pink = 14
    std.color.red = 8
    std.color.maroon = 8
    std.color.green = 11
    std.color.lime = 3
    std.color.darkgreen = 3
    std.color.skyblue = 12
    std.color.blue = 12
    std.color.darkblue = 1
    std.color.purple = 13
    std.color.violet = 2
    std.color.darkpurple = 2
    std.color.beige = 15
    std.color.brown = 4
    std.color.darkbrown = 4
    std.color.black = 0
    std.color.blank = 0
    std.color.magenta = 2
end

local P = {
    install = install
}

return P
