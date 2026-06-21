local test = require('tests/framework/microtest')
local profile = require('source/engine/core/profile')

function test_profile_skips_engine_sources()
    assert(profile.should_capture_src('source/engine/api/raw/bus.lua') == false)
    assert(profile.should_capture_src('@/home/guily/Dev/zedia/gly-engine/source/shared/engine/loadgame.lua') == false)
    assert(profile.should_capture_src('source/third_party/2dengine_profile.lua') == false)
end

function test_profile_keeps_application_sources()
    assert(profile.should_capture_src('samples/pong/game.lua') == true)
    assert(profile.should_capture_src('@/home/guily/game/src/main.lua') == true)
end

function test_profile_enable_sources()
    assert(profile.is_enabled(true) == true)
    assert(profile.is_enabled('--profile') == true)
    assert(profile.is_enabled({profile=true}) == true)
    assert(profile.is_enabled({'--profile'}) == true)
    assert(profile.is_enabled(false, nil, '0') == false)
end

function test_profile_stub_keeps_service_shape()
    local engine = {}
    local stub = profile.install(engine, false)
    local called = false

    assert(engine.profile == stub)
    assert(stub.enabled == false)

    stub.start('node loop')
    stub.call('node loop', function()
        called = true
    end)
    stub.stop('node loop')
    stub.report()

    assert(called == true)
end

test.unit(_G)
