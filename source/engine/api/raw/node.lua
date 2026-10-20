local dom      = require('source/engine/browser/dom')
local pause    = require('source/engine/browser/pause')
local loadgame = require('source/shared/engine/loadgame')

-- lifecycle events are fired by dom/navigator directly, not via the bus.
-- root (uid=0) is the exception: its init/exit are still bus-driven since
-- root bypasses node_add and never gets lifecycle.spawn called.
local LIFECYCLE = { init=true, exit=true, focus=true, unfocus=true, hover=true, unhover=true }
local node_default = require('source/shared/var/object/node')

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
--! @todo remove emit from std.node in 0.4.X
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
--! @decorator
--! @param [in/out] application
--! @par Example
--! @code{.java}
--! local game = std.node.load('samples/awesome/game.lua')
--! std.node.spawn(game)
--! @endcode
local function spawn(engine)
    return function(application, parent)
        dom.node_add(engine.dom, application, {parent=parent or engine.current})
        return application
    end
end

--! @short unregister node from event bus
--! @decorator
--! @par Example
--! @code{.java}
--! if std.milis > minigame_limit_time then
--!    std.node.kill(minigame)
--! end
--! @endcode
local function kill(engine)
    return function(application)
        dom.node_del(engine.dom, application)
    end
end

--! @short disable node callback
--! @decorator
--! @brief stop receive specific event int the application
--! @par Example
--! @code{.java}
--! if not paused and std.key.press.menu then
--!     std.node.pause(minigame, 'loop')
--! end
--! @endcode
local function node_pause(engine)
    return function(application, key)
        pause.node_pause(engine.dom, application, key)
    end
end

--! @short enable node callback
--! @decorator
--! @brief return to receiving specific event in the application
--! @par Example
--! @code{.java}
--! if paused and std.key.press.menu then
--!     std.node.resume(minigame, 'loop')
--! end
--! @endcode
local function node_resume(engine)
    return function(application, key)
        pause.node_resume(engine.dom, application, key)
    end
end
--! @}
--! @}

local function install(std, engine)
    std.node = std.node or {}

    std.node.kill   = kill(engine)
    std.node.pause  = node_pause(engine)
    std.node.spawn  = spawn(engine)
    std.node.resume = node_resume(engine)
    std.node.load   = load

    std.node.emit = function(application, key, a, b, c, d, e, f)
        return emit(std, application, key, a, b, c, e, f)
    end

    std.bus.listen_all(function(key, a, b, c, d, e, f)
        dom.bus(engine.dom, key, function(node)
            engine.current = node
            engine.offset_x = node.config.offset_x
            engine.offset_y = node.config.offset_y

            if node.callbacks[key] and (node.config.uid == 0 or not LIFECYCLE[key]) then
                xpcall(function() node.callbacks[key](node.data, std, a, b, c, d, e, f) end, engine.handler)
            end
        end)
    end)
end

local P = {
    install = install
}

return P
