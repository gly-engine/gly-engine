local function install(std)
    std.color = std.color or {}
--! @defgroup std
--! @{
--! @defgroup color
--! @{
--! @par Example
--! @code{.java}
--! std.draw.clear(std.color.black)
--! std.draw.color(std.color.white)
--! @endcode
--! @par Pallete
--! @call color
--! @par List
--! @call code
    std.color.white = 0xFFFFFFFF
    std.color.lightgray = 0xC8CCCCFF
    std.color.gray = 0x828282FF
    std.color.darkgray = 0x505050FF
    std.color.yellow = 0xFDF900FF
    std.color.gold = 0xFFCB00FF
    std.color.orange = 0xFFA100FF
    std.color.pink = 0xFF6DC2FF
    std.color.red = 0xE62937FF
    std.color.maroon = 0xBE2137FF
    std.color.green = 0x00E430FF
    std.color.lime = 0x009E2FFF
    std.color.darkgreen = 0x00752CFF
    std.color.skyblue = 0x66BFFFFF
    std.color.blue = 0x0079F1FF
    std.color.darkblue = 0x0052ACFF
    std.color.purple = 0xC87AFFFF
    std.color.violet = 0x873CBEFF
    std.color.darkpurple = 0x701F7EFF
    std.color.beige = 0xD3B083FF
    std.color.brown = 0x7F6A4FFF
    std.color.darkbrown = 0x4C3F2FFF
    std.color.black = 0x000000FF
    std.color.blank = 0x00000000
    std.color.magenta = 0xFF00FFFF
--! @call endcode
--! @}
--! @}
end

local P = {
    install = install
}

return P
