local function m6b2()
local ____exports = {}
____exports.meta = {title = "itch.gly.sh", version = "0.0.1", description = "non-browser client itch-io to play homebrew games with libretro "}
local function Card(____bindingPattern0, std)
local title = ____bindingPattern0.title
return std.h(
"node",
{
hover = function() return std.ui.focus() end,
draw = function(____, ____self)
local ____opt_0 = std.ui
if ____opt_0 and ____opt_0.isFocused() then
std.draw.color(std.color.red)
else
std.draw.color(std.color.skyblue)
end
std.draw.rect(
0,
0,
0,
50,
50
)
std.draw.color(std.color.white)
std.text.print(0, 0, title)
end
}
)
end
____exports.callbacks = {
load = function(_, std)
std.h(
"slide",
{class = "2x5"},
std.h(Card, {title = "foo"}),
std.h(Card, {title = "bar"}),
std.h(Card, {title = "z"}),
std.h(Card, {title = "h"}),
std.h(Card, {title = "zig"}),
std.h(Card, {title = "zag"}),
std.h(Card, {title = "zoom"}),
std.h(Card, {title = "zop"}),
std.h(Card, {title = "fo123213o"}),
std.h(Card, {title = "dd"}),
std.h(Card, {title = "zzz"}),
std.h(Card, {title = "hzz"}),
std.h(Card, {title = "zizg"}),
std.h(Card, {title = "zagzz"}),
std.h(Card, {title = "zoozzm"}),
std.h(Card, {title = "zozp"})
)
end,
key = function(_, std)
if std.key.press.left then
std.ui.focus("left")
end
if std.key.press.right then
std.ui.focus("right")
end
if std.key.press.down then
std.ui.focus("down")
end
if std.key.press.up then
std.ui.focus("up")
end
end
}
return ____exports
end
return m6b2()
