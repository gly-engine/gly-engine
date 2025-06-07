local ev_prefixes = {
    'pre_',
    '',
    'post_'
}

local buses = {
    list = {},
    dict = {},
    queue = {},
    pause = {},
    all = {}
}

local must_abort = false

--! @defgroup std
--! @{
--! @defgroup bus
--! @{
--! @warning <strong>This is an advanced API!</strong>@n only for advanced programmers,
--! You might be lost if you are a beginner.
--! @details You can get inspired by some explanations about how the event bus works in the JavaScript framework called Vue, 
--! it is very similar, but there is only 1 global bus that the engine itself uses to work. 
--!
--! ## Event Bus System
--! broadcasts some event to all nodes.
--!
--! @startuml
--! process event_bus as "Event Bus"
--! artifact node_1 as "Node 1"
--! artifact node_2 as "Node 2"
--! artifact node_3 as "Node 3"
--! node_2 -up-> event_bus
--! event_bus --> node_1
--! event_bus --> node_3
--! @enduml
--!
--! @li Node 2
--! @code{.java}
--! std.bus.emit('say', 'ola mundo')
--! @endcode
--!
--! @li Node 1 / Node 3
--! @code{.java}
--! std.bus.listen('say', function(msg) print(msg) end)
--! @endcode
--!
--! ## Event Callbacks (Deep Overview)
--! The event system is also used to control events from the engine itself,
--! where the core triggers an action and it is propagated to the internal modules,
--! and to the game and its components (nodes).
--!
--! @startuml
--! folder core {
--!    component love2d {
--!      action trigger_a as "Trigger A"
--!    }
--! }
--! 
--! folder engine {
--!   component module_1 as "Module 1" {
--!     agent function_1_a as "Function A"
--!   }
--!   component module_2 as "Module 2" {
--!     agent function_2_a as "Function A"
--!   }
--! }
--! 
--! process event_bus as "Event Bus"
--! 
--! artifact node_1 as "Node 1"{
--!  agent callback_1_a as "Callback A"
--! }
--! 
--! artifact node_2 as "Node 2"{
--!  agent callback_2_a as "Callback A"
--!  agent function_3_a as "Function A"
--! }
--! 
--! trigger_a --> event_bus
--! event_bus -up-> function_1_a
--! event_bus -up-> function_2_a
--! event_bus --> callback_1_a
--! event_bus --> callback_2_a
--! event_bus --> function_3_a
--! @enduml
--!
--! @li Love2d
--! @code{.java}
--! function love.load()
--!     love.draw = std.bus.trigger('draw')
--! end
--! @endcode
--! 
--! @li Module 1 / Module 2
--! @code{.java}
--! function draw(std)
--! end
--! 
--! function install(std)
--!     std.bus.listen_std('draw', draw)
--! end
--! @endcode
--! 
--! @li Node 1
--! @code{.java}
--! return {
--!     meta = {
--!         title = 'World'
--!     },
--!     callbacks = {
--!         draw = function(std) end
--!     }
--! }
--! @endcode
--! @li Node 2
--! @code{.java}
--! return {
--!     meta = {
--!         title = 'Player'
--!     },
--!     callbacks = {
--!         load = function(std)
--!             std.bus.listen_std_data('draw', function() end)
--!         end,
--!         draw = function(std) end
--!     }
--! }
--! @endcode

--! @short stop current signal
--! @brief This interrupts the signal to the next nodes,
--! this also applies to the engine itself and prevents lifecycle events.
--! @note reckless use can lead to bad behavior.
--! @par Example
--! @code{.java}
--! local function quit(std, game)
--!     std.bus.abort()
--! end
--! @endcode
local function abort()
    must_abort = true
end

--! @cond
local function emit_next(key, a, b, c, d, e, f)
    buses.queue[#buses.queue + 1] = {key, a, b, c, d, e, f}
end
--! @endcond

--! @short send unique event
--! @hideparam prefixes
--! @details
--! broadcast message for all nodes.
--!
--! @par Alternatives
--! @li @b std.bus.emit_next queue to be sent in the next frame instead of immediately.
--! but it doesn't work for @c draw event.
--!
--! @par Joke
--! Yes, @c abcdef is faster to implement and execute.
--! If you need more parameters than that, the problem is in your code.
--! @n In fact, love2d also does the same thing.
--! @li https://love2d.org/wiki/love.event
--!
--! @par Example
--! @code
--! std.bus.emit('on_shoot', x1, y1, x2, y2)
--! @endcode
local function emit(prefixes, key, a, b, c, d, e, f)
    local index1, index2, index3 = 1, 1, 1

    while index1 <= #prefixes do
        index2 = 1
        local prefix = prefixes[index1]
        local topic = prefix..key
        local bus = buses.dict[topic]

        while not must_abort and bus and index2 <= #bus do
            local func = bus[index2]
            if not buses.pause[func] then
                func(a, b, c, d, e, f)
            end
            index2 = index2 + 1
        end

        index3 = 1
        while index3 <= #buses.all do
            buses.all[index3](topic, a, b, c, d, e, f)
            index3 = index3 + 1
        end

        index1 = index1 + 1
    end
    must_abort = false
end

--! @short sender event function
--! @par Example
--! @code
--! love.filedropped = std.bus.trigger('file_dropped')
--! @endcode
local function trigger(key)
    return function (a, b, c, d, e, f)
        emit(ev_prefixes, key, a, b, c, d, e, f)
    end
end

--! @short subscribe event
--! @par Alternatives
--! @li @b std.bus.listen_std receive message after @c std
--! @li @b std.bus.listen_std_data receive message after @c std and @c data
--! @li @b std.bus.listen_std_engine receive message after @c std and @c engine
--! @li @b std.bus.listen_all receive message without @c key topic, because applies to all events.
--! @par Example
--! @code
--! std.bus.listen('player_death', function()
--!     print('game over!')
--! end)
--! @endcode
local function listen(key, handler_func)
    if not key or not handler_func then return end
    if not buses.dict[key] then
        buses.list[#buses.list + 1] = key
        buses.dict[key] = {}
    end
    local index = #buses.dict[key] + 1
    buses.dict[key][index] = handler_func 
end

--! @cond
local function listen_all(handler_func)
    buses.all[#buses.all + 1] = handler_func
end
--! @endcond

--! @}
--! @}

local function install(std, engine)
    std.bus = std.bus or {}

    std.bus.abort = abort
    std.bus.listen = listen
    std.bus.trigger = trigger
    std.bus.emit_next = emit_next
    std.bus.listen_all = listen_all

    engine.bus_emit_ret = function(key, a)
        emit({'ret_'}, key, a)
    end

    std.bus.emit = function(key, a, b, c, d, e, f)
        emit(ev_prefixes, key, a, b, c, d, e, f)
    end

    std.bus.listen_std = function(key, handler_func)
        listen(key, function(a, b, c, d, e, f)
            handler_func(std, a, b, c, d, e, f)
        end)
    end

    std.bus.listen_std_data = function(key, handler_func)
        listen(key, function(a, b, c, d, e, f)
            handler_func(std, engine.current.data, a, b, c, d, e, f)
        end)
    end

    std.bus.listen_std_engine = function(key, handler_func)
        listen(key, function(a, b, c, d, e, f)
            handler_func(std, engine, a, b, c, d, e, f)
        end)
    end

    listen('pre_loop', function()
        local index = 1
        while index <= #buses.queue do
            local pid = buses.queue[index]
            emit({''}, pid[1], pid[2], pid[3], pid[4], pid[5], pid[6])
            index = index + 1
        end
        buses.queue = {}
    end)

    return {
        bus=std.bus
    }
end

local P = {
    install=install
}

return P
