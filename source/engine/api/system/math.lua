--! @defgroup std
--! @{
--! @defgroup math
--! @{
--! @details 
--! @pre @b require @c math.random to use: @n @n
--! @c std.math.random
--!
--! @n
--! @pre @b require @c math to use: @n @n
--! @call listlibmath

--! @short std.math.abs
--! @brief module
--! @par Equation
--! @startmath
--! |value|
--! @endmath
--! @param[in] value
--! @retval value as positive number
local function abs(value)
    if value < 0 then
        return -value
    end
    return value
end

--! @short std.math.clamp
--! @param[in] value The value to clamp
--! @param[in] value_min The minimum value that value can be clamped to.
--! @param[in] value_max The maximum value that value can be clamped to.
--! @retval value @n `if value_min <= value <= value_max`
--! @retval value_min @n `if value < value_min`
--! @retval value_max @n `if value > value_max`
local function clamp(value, value_min, value_max)
    if value < value_min then
        return value_min
    elseif value > value_max then
        return value_max
    else
        return value
    end
end

--! @short std.math.clamp2
--! @note similar to @ref clamp "std.math.clamp" but cyclical.
--! @par Equation
--! @startmath
--! (value - value\_min) \mod (value\_max - value\_min + 1) + value\_min
--! @endmath
--! @param[in] value The value to clamp
--! @param[in] value_min The minimum value that value can be clamped to.
--! @param[in] value_max The maximum value that value can be clamped to.
local function clamp2(value, value_min, value_max)
    return (value - value_min) % (value_max - value_min + 1) + value_min
end

--! @short std.math.dir
--! @brief direction
--! @param[in] value
--! @param[in] alpha @c default=0
--! @retval -1 less than alpha @n `if value < -alpha`
--! @retval 1 greater than alpha @n `if value > alpha`
--! @retval 0 when is in alpha @n `if abs(alpha) <= aplha`
--! @par Example
--! @code{.java}
--! local sprites = {
--!   [-1] = game.spr_player_left,
--!   [1] = game.spr_player_right,
--!   [0] = game.player_sprite
--! }
--! game.player_sprite = sprites[std.math.dir(game.player_speed_x)]
--! @endcode
local function dir(value, alpha)
    alpha = alpha or 0
    if value < -alpha then
        return -1
    elseif value > alpha then
        return 1
    else
        return 0
    end
end

--! @short std.math.dis
--! @brief euclidean distance
--! @note when you are running in <b>Lua without <u>floating point</u> support</b>,@n
--! the result will be like @ref dis2 "std.math.dis2" since there is no square root support. 
--! @par Equation
--! @startmath
--! \sqrt{(x_2 - x_1)^2 + (y_2 - y_1)^2}
--! @endmath
--! @param[in] x1 The x coordinate of the first point.
--! @param[in] y1 The y coordinate of the first point.
--! @param[in] x2 The x coordinate of the second point.
--! @param[in] y2 The y coordinate of the second point.
--! @return distance between the two points (x1, y1) and (x2, y2).
local function dis(x1,y1,x2,y2)
    local sqr = 1/2
    return ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ (sqr ~= 0 and sqr or 1)
end

--! @short std.math.dis2
--! @brief quadratic distance
--! @note this is an optimization of @ref dis "std.math.dist" but it cannot be used to calculate collisions.
--! @par Equation
--! @startmath
--! (x_2 - x_1)^2 + (y_2 - y_1)^2
--! @endmath
--! @param[in] x1 The x coordinate of the first point.
--! @param[in] y1 The y coordinate of the first point.
--! @param[in] x2 The x coordinate of the second point.
--! @param[in] y2 The y coordinate of the second point.
--! @return distance between the two points (x1, y1) and (x2, y2).
local function dis2(x1,y1,x2,y2)
    return (x2 - x1) ^ 2 + (y2 - y1) ^ 2
end

--! @short std.math.dis3
--! @brief metric used to determine the distance between two points in a grid-like path
--! @par Equation
--! @startmath
--! |x_2 - x_1| + |y_2 - y_1|
--! @endmath
--! @param[in] x1 The x coordinate of the first point.
--! @param[in] y1 The y coordinate of the first point.
--! @param[in] x2 The x coordinate of the second point.
--! @param[in] y2 The y coordinate of the second point.
--! @return distance between the two points (x1, y1) and (x2, y2).
local function dis3(x1,y1,x2,y2)
    return abs(x1 - x2) + abs(x2 - y2)
end

--! @short std.math.lerp
--! @brief linear interpolation
--! @par Equation
--! @startmath
--! a + \alpha \cdot (b - a)
--! @endmath
--! @param[in] a The starting value
--! @param[in] b The ending value
--! @param[in] alpha The interpolation parameter, typically in the range [0, 1].
--! @return The interpolated value between 'a' and 'b' based on 'alpha'.
local function lerp(a, b, alpha)
    return a + alpha * ( b - a )
end 

--! @short std.math.map
--! @brief re-maps
--! @li <https://www.arduino.cc/reference/en/language/functions/math/map>
--!
--! @par Equation
--! @startmath
--! (value - in\_min) \cdot \frac{(out\_max - out\_min)}{(in\_max - in\_min)} + out\_min
--! @endmath
--! @param[in] value The value to be mapped from the input range to the output range.
--! @param[in] in_min The minimum value of the input range.
--! @param[in] in_max The maximum value of the input range.
--! @param[in] out_min The minimum value of the output range.
--! @param[in] out_max The maximum value of the output range.
--! @return The mapped value in the output range corresponding to 'value' in the input range.
local function map(value, in_min, in_max, out_min, out_max)
    return (value - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
end

--! @short std.math.max
--! @brief biggest number
--! @par Example
--! @code{.java}
--! local one = std.math.max(0, 1)
--! local two = std.math.max({0, 1, 2})
--! @endcode
local function max(...)
    local args = {...}
    local index = 1
    local value = nil
    local max_value = nil
    
    if #args == 1 then
        args = args[1]
    end

    while index <= #args do
        value = args[index]
        if max_value == nil or value > max_value then
            max_value = value
        end
        index = index + 1
    end

    return max_value
end

--! @short std.math.min
--! @brief smallest number
--! @par Example
--! @code{.java}
--! local one = std.math.max(1, 2, 3)
--! local two = std.math.max({2, 3, 4})
--! @endcode
local function min(...)
    local args = {...}
    local index = 1
    local value = nil
    local min_value = nil
    
    if #args == 1 then
        args = args[1]
    end

    while index <= #args do
        value = args[index]
        if min_value == nil or value < min_value then
            min_value = value
        end
        index = index + 1
    end

    return min_value
end

--! @pre require @c math.wave
local function sine(t, freq)
    local math = require('math')
    return math.pi and math.sin(2 * math.pi * freq * t) or 1
end

--! @cond
local function ramp(t, freq, ratio)
    t = (t / 2) % (1 / freq) * freq
    if t < ratio then
        return 2 * t / ratio - 1
    else
        return (2 * t - ratio - 1) / (ratio - 1)
    end
end
--! @endcond

--! @pre require @c math.wave
local function saw(t, freq)
    return ramp(t, freq, 1)
end

--! @pre require @c math.wave
local function triangle(t, freq)
    return ramp(t, freq, 1/2)
end

--! @cond
local function rect(t, freq, duty)
    duty = 1 - duty * 2
    return saw(t, freq) > duty and 1 or -1
end
--! @endcond

--! @pre require @c math.wave
local function square(t, freq)
    return rect(t, freq, 1/2)
end

--! @}
--! @}

local function install(std)
    std.math = std.math or {}
    std.math.abs=abs
    std.math.clamp=clamp
    std.math.clamp2=clamp2
    std.math.dir=dir
    std.math.dis=dis
    std.math.dis2=dis2
    std.math.dis3=dis3
    std.math.lerp=lerp
    std.math.map=map
    std.math.max=max
    std.math.min=min
end

local function install_wave(std)
    std.math = std.math or {}
    std.math.sine=sine
    std.math.saw=saw
    std.math.square=square
    std.math.triangle=triangle
end

local function install_clib(std)
    local math = require('math')
    std.math = std.math or {}
    std.math.acos=math.acos
    std.math.asin=math.asin
    std.math.atan=math.atan
    std.math.atan2=math.atan2
    std.math.ceil=math.ceil
    std.math.cos=math.cos
    std.math.cosh=math.cosh
    std.math.deg=math.deg
    std.math.exp=math.exp
    std.math.floor=math.floor
    std.math.fmod=math.fmod
    std.math.frexp=math.frexp
    std.math.huge=math.huge
    std.math.ldexp=math.ldexp
    std.math.log=math.log
    std.math.log10=math.log10
    std.math.modf=math.modf
    std.math.pi=math.pi
    std.math.pow=math.pow
    std.math.rad=math.rad
    std.math.sin=math.sin
    std.math.sinh=math.sinh
    std.math.sqrt=math.sqrt
    std.math.tan=math.tan
    std.math.tanh=math.tanh
end

local function install_clib_random(std)
    local math = require('math')
    std.math = std.math or {}
    std.math.random = function(a, b)
        a = a and math.floor(a)
        b = b and math.floor(b)
        return math.random(a, b)
    end
end

local P = {
    install = install,
    wave = {
        install = install_wave
    },
    clib = {
        install = install_clib
    },
    clib_random = {
        install = install_clib_random
    }
}

return P;
