local zeebo_module = require('src/lib/common/module')
local node_default = require('src/lib/object/node')

local buses = {
    list = {},
    inverse_list = {},
    pause = {},
}

--! @defgroup std
--! @{
--! @defgroup node
--! @{
--! @warning <strong>This is an advanced API!</strong>@n only for advanced programmers,
--! You might be lost if you are a beginner.
--!
--! ## Event Direct Message
--! @startuml
--! artifact node_1 as "Node 1"
--! artifact node_2 as "Node 2"
--! node_1 -> node_2
--! @enduml
--! @li Node 1
--! @code{.java}
--! std.node.emit(node_2, 'say', 'hello!')
--! @endcode
--!
--! ## Event Bus Registering
--! @par Parents
--! @startmindmap
--! * Root
--! ** Node 1
--! *** Node 2
--! ** Node 3
--! @endmindmap
--! @li Root
--! @code{.java}
--! std.node.spawn(node_1)
--! std.node.spawn(node_3)
--! @endcode
--! @li Node 1
--! @code{.java}
--! std.node.spawn(node_2)
--! @endcode
--!
--! @par Custom Events
--! @startuml
--! artifact node_1 as "Node 1"
--! artifact node_2 as "Node 2"
--! artifact node_3 as "Node 3"
--! 
--! process event_bus as "Event Bus" 
--! node_1 .> node_2: spawn
--! event_bus --> node_2
--! event_bus <-- node_3
--! @enduml
--!
--! @li Node 3
--! @code{.java}
--! std.bus.emit('say', 'hello for everyone!')
--! @endcode
--!
--! @par Engine Events
--! @startuml
--! folder core {
--!  folder love2d
--! }
--! process event_bus as "Event Bus"
--! artifact node_1 as "Node 1"
--! artifact node_2 as "Node 2"
--! 
--! love2d -> event_bus: event
--! event_bus --> node_2: event
--! node_1 .> node_2:spawn
--! @enduml

--! @hideparam std
--! @short send event to node
--! @par Tip
--! You can send message to "not spawned" node, as if he were an orphan.
--! @par Alternatives
--! @li @b std.node.emit_root send event to first node.
--! @li @b std.node.emit_parent send event to the node that registered current.
local function emit(std, application, key, a, b, c, d, e, f)
    local callback = application.callbacks[key]
    if not buses.pause[key..tostring(application)] and callback then
        return callback(std, application.data, a, b, c, d, e, f)
    end
    return nil
end

--! @short create new node
--! @note When build the main game file, it will be directly affected by the @b build.
--! @param [in] application
--! @return node
--! @par Example
--! @code{.java}
--! local game = std.node.load('samples/awesome/game.lua')
--! print(game.meta.title)
--! @endcode
local function load(application)
    return zeebo_module.loadgame(application, node_default)
end

--! @short register node to event bus
--! @hideparam std
--! @hideparam engine
--! @param [in/out] application
--! @par Example
--! @code{.java}
--! local game = std.node.load('samples/awesome/game.lua')
--! std.node.spawn(game)
--! @endcode
local function spawn(engine, application)
    if not application or buses.inverse_list[application] then return end
    local depth = 1
    local index = #buses.list + 1
    buses.list[index] = application
    buses.inverse_list[application] = index
    if engine.current then
        application.config.parent = engine.current
        depth = (engine.current.config.depth or 0) + 1
    end
    application.config.depth = depth
end

--! @short unregister node from event bus
--! @par Example
--! @code{.java}
--! if std.milis > minigame_limit_time then
--!    std.node.kill(minigame)
--! end
--! @endcode
local function kill(application)
    local index = application and buses.inverse_list[application]
    local last_item = #buses.list

    while index and index <= last_item do
        buses.list[index] = buses.list[index + 1]
        index = index + 1
    end
    
    if application then
        buses.inverse_list[application] = nil
        application.config.parent = nil
    end
end

--! @short disable node callback
--! @brief stop receive specific event int the application
--! @par Example
--! @code{.java}
--! if not paused and std.key.press.menu then
--!     std.node.pause(minigame, 'loop')
--! end
--! @endcode
local function pause(application, key)
    buses.pause[key..tostring(application)] = true
end

--! @short enable node callback
--! @brief return to receiving specific event in the application
--! @par Example
--! @code{.java}
--! if paused and std.key.press.menu then
--!     std.node.resume(minigame, 'loop')
--! end
--! @endcode
local function resume(application, key)
    buses.pause[key..tostring(application)] = false
end
--! @}
--! @}

local function clear_bus()
    local index = 1
    while index <= #buses.list do
        local application = buses.list[index]
        buses.inverse_list[application] = nil
        application.config.parent = nil
        buses.list[index] = nil
        index = index + 1
    end
end

--! note no remove
local function event_bus(std, engine, key, a, b, c, d, e, f)
    local index = 1
    local count = 0
    local depth = 0

    repeat
        index = 1
        count = 0
        depth = depth + 1
        while index <= #buses.list do
            local application = buses.list[index]
            if application.config.depth == depth then
                count = count + 1
                if engine.current ~= application then
                    local node = application
                    local safe_depth = 0
                    engine.current = application
                    engine.offset_x = 0
                    engine.offset_y = 0
                    while node and safe_depth < 100 do
                        if safe_depth > 50 then
                            error('fatal error parent three')
                        end
                        engine.offset_x = engine.offset_x + node.config.offset_x
                        engine.offset_y = engine.offset_y + node.config.offset_y
                        node = node.config.parent
                        safe_depth = safe_depth + 1
                    end
                end
        
                local ret = emit(std, application, key, a, b, c, d, e, f)
                
                if ret ~= nil then
                    engine.bus_emit_ret(key, ret)
                end
            end
            index = index + 1
        end
    until count == 0
end

local function install(std, engine)
    std.node = std.node or {}

    std.node.kill = kill
    std.node.pause = pause
    std.node.resume = resume
    std.node.load = load

    std.bus.listen('clear_all', clear_bus)

    std.node.spawn = function (application)
        spawn(engine, application)
    end

    std.bus.listen_all(function(key, a, b, c, d, e, f)
        event_bus(std, engine, key, a, b, c, d, e, f)
    end)

    std.node.emit = function(application, key, a, b, c, d, e, f)
        return emit(std, application, key, a, b, c, e, f)
    end

    std.node.emit_root = function(key, a, b, c, d, e, f)
        return emit(std, engine.root, key, a, b, c, e, f)
    end

    std.node.emit_parent = function(key, a, b, c, d, e, f)
        return emit(std, engine.current.config.parent, key, a, b, c, e, f)
    end
end

local P = {
    install=install
}

return P
