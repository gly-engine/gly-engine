local engine_game = require('source/engine/api/system/app')
local test = require('tests/framework/microtest')

function test_app_reset()
    local index = 1
    local buses = {}
    local std = {
        node = {},
        bus = {
            listen = function() end,
            emit = function(key)
                buses[key] = index
                index = index + 1
            end
        }
    }
    
    local config = {
        quit = function()
            print("Config quit foi chamado!")
        end
    }

    zeebo_game = engine_game.install(std, {}, {})
    zeebo_game.reset()

    assert(buses.exit == 1)
    assert(buses.init == 2)
    assert(index == 3)
    std.bus:emit('post_quit')
end

function test_app_reset_no_node()
    local exit_called = false
    local init_called = false

    local std = {
        bus = {
            listen = function() end,
            emit = function() end
        }
    }


    local engine = {
        root = {
            data = {},
            callbacks = {}
        }
    }

    engine.root.callbacks.exit = function(std_param, data_param)
        assert(std_param == std)
        assert(data_param == engine.root.data)
        exit_called = true
    end

    engine.root.callbacks.init = function(std_param, data_param)
        assert(std_param == std)
        assert(data_param == engine.root.data)
        init_called = true
    end
    zeebo_game = engine_game.install(std, engine, {})
    zeebo_game.reset()

    assert(exit_called == true)
    assert(init_called == true)
end

function test_app_exit()
    local index = 1
    local buses = {}
    local std = {
        bus = {
            listen = function() end,
            emit = function(key)
                buses[key] = index
                index = index + 1
            end
        }
    }

    zeebo_game = engine_game.install(std, {}, {})
    zeebo_game.exit()

    assert(buses.exit == 1)
    assert(buses.quit == 2)
    assert(index == 3)
end

function test_app_title()

    local function mock_set_title(window_name)
        assert(window_name == "Teste")
    end

    local std = {
        bus = {
            listen = function() end,
            emit = function() end
        },
        app ={
            title = nil
        }
    }
    local config = {
        set_title = mock_set_title
    }

    local zeebo_game = engine_game.install(std, {}, config)

    zeebo_game.title("Teste")

end

function test_app_install()
    local exit_called = false
    local init_called = false
    local quit_called = false

    local std = {
        bus = {
            listen = function(event, callback)
                if event == 'post_quit' then
                    callback()  
                end
            end,
            emit = function() end
        }
    }

    local engine = {
        root = {
            data = {},
            callbacks = {}
        }
    }

    engine.root.callbacks.exit = function(std_param, data_param)
        assert(std_param == std)
        assert(data_param == engine.root.data)
        exit_called = true
    end

    engine.root.callbacks.init = function(std_param, data_param)
        assert(std_param == std)
        assert(data_param == engine.root.data)
        init_called = true
    end

    local config = {
        set_title = function(window_name)
            assert(window_name == "Test Window")
        end,
        get_fps = 60,
        quit = function()
            quit_called = true  
        end
    }

    local zeebo_game = engine_game.install(std, engine, config)

    assert(zeebo_game.title ~= nil)
    assert(zeebo_game.exit  ~= nil)
    assert(zeebo_game.reset ~= nil)
    assert(zeebo_game.get_fps == 60)

    zeebo_game.title("Test Window")

    zeebo_game.reset()

    assert(exit_called == true)
    assert(init_called == true)
    assert(quit_called == true)
end

test.unit(_G)
