local tree = require('source/shared/engine/tree')
local loadgame = require('source/shared/engine/loadgame')
local node_default = require('source/shared/var/object/node')
local util_decorator = require('source/shared/functional/decorator')

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
    return loadgame.script(application, node_default)
end

--! @short register node to event bus
--! @hideparam engine
--! @param [in/out] application
--! @par Example
--! @code{.java}
--! local game = std.node.load('samples/awesome/game.lua')
--! std.node.spawn(game)
--! @endcode
local function spawn(engine, application)
    tree.node_add(engine.dom, application, {parent=engine.current})
    return application
end

--! @short unregister node from event bus
--! @hideparam engine
--! @par Example
--! @code{.java}
--! if std.milis > minigame_limit_time then
--!    std.node.kill(minigame)
--! end
--! @endcode
local function kill(engine, application)
    tree.node_del(engine.dom, application)
end

--! @short disable node callback
--! @hideparam engine
--! @brief stop receive specific event int the application
--! @par Example
--! @code{.java}
--! if not paused and std.key.press.menu then
--!     std.node.pause(minigame, 'loop')
--! end
--! @endcode
local function pause(engine, application, key)
    tree.node_pause(engine.dom, application, key)
end

--! @short enable node callback
--! @hideparam engine
--! @brief return to receiving specific event in the application
--! @par Example
--! @code{.java}
--! if paused and std.key.press.menu then
--!     std.node.resume(minigame, 'loop')
--! end
--! @endcode
local function resume(engine, application, key)
    tree.node_resume(engine.dom, application, key)
end
--! @}
--! @}

local function install(std, engine)
    std.node = std.node or {}

    std.node.kill = util_decorator.prefix1(engine, kill)
    std.node.pause = util_decorator.prefix1(engine, pause)
    std.node.resume = util_decorator.prefix1(engine, resume)
    std.node.load = load

    std.node.spawn = function (application)
        return spawn(engine, application)
    end

    std.node.emit = function(application, key, a, b, c, d, e, f)
        return emit(std, application, key, a, b, c, e, f)
    end

    std.bus.listen_all(function(key, a, b, c, d, e, f)
        tree.bus(engine.dom, key, function(node)
            engine.current = node
            engine.offset_x = node.config.offset_x
            engine.offset_y = node.config.offset_y
            if node.callbacks[key] then
                node.callbacks[key](node.data, std, a, b, c, d, e, f)
            end
        end)
    end)
end

local P = {
    install=install
}

return P
