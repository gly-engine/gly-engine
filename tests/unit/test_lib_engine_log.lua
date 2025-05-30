local test = require('src/lib/util/test')
local engine_log = require('source/engine/api/debug/log')

local function printers(msg)
    return {
        fatal = function(t)
            msg.fatal = t    
        end,
        error = function(t)
            msg.error = t    
        end,
        warn = function(t)
            msg.warn = t    
        end,
        debug = function(t)
            msg.debug = t    
        end,
        info = function(t)
            msg.info = t    
        end
    }
end

function test_helloworld()
    local std, msg = {}, ''
    engine_log.install(std, {}, {info=function(t) msg = t end})
    std.log.info('helloworld')
    assert(msg == 'helloworld')
end

function test_level_error()
    local std, msg = {}, ''
    engine_log.install(std, {}, {})
    local ok = pcall(std.log.level, 42)
    std.log.info('helloworld')
    assert(ok == false)
end

function test_level_per_number()
    local std = {}
    local msg = {}
    
    engine_log.install(std, {}, printers(msg))
    
    std.log.level(1)
    std.log.fatal('foo1')
    std.log.error('foo2')
    std.log.warn('foo3')
    std.log.debug('foo5')
    std.log.info('foo6')

    assert(msg.fatal == 'foo1')
    assert(msg.error == nil)
    assert(msg.warn == nil)
    assert(msg.debug == nil)
    assert(msg.info == nil)
end

function test_level_per_name()
    local std = {}
    local msg = {}
    
    engine_log.install(std, {}, printers(msg))
    
    std.log.level('error')
    std.log.fatal('bar1')
    std.log.error('bar2')
    std.log.warn('bar3')
    std.log.debug('bar4')
    std.log.info('bar6')

    assert(msg.fatal == 'bar1')
    assert(msg.error == 'bar2')
    assert(msg.warn == nil)
    assert(msg.debug == nil)
    assert(msg.info == nil)
end

function test_level_per_func()
    local std = {}
    local msg = {}
    
    engine_log.install(std, {}, printers(msg))
    
    std.log.level(std.log.warn)
    std.log.fatal('z1')
    std.log.error('z2')
    std.log.warn('z3')
    std.log.debug('z4')
    std.log.info('z6')

    assert(msg.fatal == 'z1')
    assert(msg.error == 'z2')
    assert(msg.warn == 'z3')
    assert(msg.debug == nil)
    assert(msg.info == nil)
end

function test_reinit_system()
    local std = {}
    local msg1 = {}
    local msg2 = {}
    local msg3 = {}
    
    engine_log.install(std, {}, printers(msg1))
    std.log.info('ola')
    std.log.init(printers(msg2))
    std.log.info('alo')
    std.log.init(printers(msg3))
    std.log.level(std.log.debug)
    std.log.warn('hello')
    std.log.info('hi')
    
    assert(msg1.info == 'ola')
    assert(msg2.info == 'alo')
    assert(msg3.info == nil)
    assert(msg3.warn == 'hello')
end

test.unit(_G)
