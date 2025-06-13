local test = require('tests/framework/microtest')
local dsl = require('source/shared/string/dsl/requires')

function test_encode_basic()
    local spec = dsl.encode("math math.random math.wave? portuguese? *")
    assert(spec.all == true)
    assert(spec.list[1] == "math")
    assert(spec.list[2] == "math.random")
    assert(spec.list[3] == "math.wave")
    assert(spec.list[4] == "portuguese")
    assert(spec.required[1] == true)
    assert(spec.required[2] == true)
    assert(spec.required[3] == false)
    assert(spec.required[4] == false)
    assert(#spec.list == 4)
    assert(#spec.required == 4)
end

function test_should_import()
    local spec = dsl.encode("abc def?")
    assert(dsl.should_import(spec, "abc") == true)
    assert(dsl.should_import(spec, "def") == true)
    assert(dsl.should_import(spec, "xyz") == false)

    local spec2 = dsl.encode("foo bar? *")
    assert(dsl.should_import(spec2, "foo") == true)
    assert(dsl.should_import(spec2, "bar") == true)
    assert(dsl.should_import(spec2, "xyz") == true)
end

function test_missing_required()
    local spec = dsl.encode("a b? c d?")
    local imported = {['a'] = true, ['d'] = true }
    local missing = dsl.missing(spec, imported)
    assert(#missing == 1)
    assert(missing[1] == "c")

    local imported2 = {['a'] = true, ['c'] = true }
    local missing2 = dsl.missing(spec, imported2)
    assert(#missing2 == 0)
end

test.unit(_G)
