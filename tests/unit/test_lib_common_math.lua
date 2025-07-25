local test = require('tests/framework/microtest')
local math = require('math')
local engine_math = require('source/engine/api/math/basic')
local std = {}
engine_math.install(std)
local zeebo_math = std.math

function test_clamp()
    assert(zeebo_math.clamp(10, 1, 5) == 5)
    assert(zeebo_math.clamp(-10, -5, 5) == -5)
    assert(zeebo_math.clamp(3, 1, 5) == 3)
end

function test_dir()
    assert(zeebo_math.dir(2, 1) == 1)
    assert(zeebo_math.dir(-2, 1) == -1)
    assert(zeebo_math.dir(0, 1) == 0)
end

function test_dis()
    assert(zeebo_math.dis(0, 0, 3, 4) == 5)
end

function test_dis2()
    assert(zeebo_math.dis2(0, 0, 3, 4) == 25)
end

function test_dis3()
    assert(zeebo_math.dis3(0, 0, 3, 4) == 4)
end

function test_abs()
    assert(zeebo_math.abs(-5) == 5)
    assert(zeebo_math.abs(10) == 10)
end

function test_lerp()
    assert(zeebo_math.lerp(1, 5, 2) == 9)
    assert(zeebo_math.lerp(1, 5, 1) == 5)
    assert(zeebo_math.lerp(1, 5, 0) == 1)
end

function test_map()
    assert(zeebo_math.map(5, 0, 10, 0, 100) == 50)
    assert(zeebo_math.map(2, 0, 5, 0, 50) == 20)
end

function test_clamp2()
    assert(zeebo_math.clamp2(10, 1, 5) == 5)
    assert(zeebo_math.clamp2(-10, -5, 5) == 1)
    assert(zeebo_math.clamp2(10, -5, 5) == -1)
    assert(zeebo_math.clamp2(3, 1, 5) == 3)
end

function test_min()
    assert(zeebo_math.min(1, 2, 3, 4, 5) == 1)
    assert(zeebo_math.min(10, -5, 3, 0) == -5)
    assert(zeebo_math.min(-1, -2, -3) == -3)
    assert(zeebo_math.min({1, 2, 3, 4, 5}) == 1)
end

function test_max()
    assert(zeebo_math.max(1, 2, 3, 4, 5) == 5)
    assert(zeebo_math.max(10, -5, 3, 0) == 10)
    assert(zeebo_math.max(-1, -2, -3) == -1)
    assert(zeebo_math.max({1, 2, 3, 4, 5}) == 5)
end

test.unit(_G)
