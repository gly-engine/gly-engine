local test = require('tests/framework/microtest')
local engine_hash = require('source/engine/api/data/hash')

local std ={}
engine_hash.install(std, nil, {get_secret = function() return 'awesome42' end })

function test_fingerprint()
    local expected = std.hash.djb2('awesome42')
    local result = std.hash.fingerprint()
    assert(expected == result)
end

function test_diff_hash_foo_bar()
    local foo = std.hash.djb2('foo')
    local bar = std.hash.djb2('bar')
    assert(foo ~= bar)
end

function test_collision_stylist_subgenera()
    local stylist = std.hash.djb2('stylist')
    local subgenera = std.hash.djb2('subgenera')
    assert(stylist == subgenera)
end

test.unit(_G)
