local memory_dict_unload = {}
local memory_dict = {}
local memory_list = {}

--! @defgroup std
--! @{
--! @defgroup mem
--! @{
--! @details A Garbage Collector System and also mangament manual of memory.

local function cache_get(key)
    return memory_dict[key]
end

local function cache_set(key, load_func, unload_func)
    local value = load_func()
    memory_list[#memory_list + 1] = key
    memory_dict_unload[key] = unload_func
    memory_dict[key] = value
end

--! @par Example
--! @code
--! local function slow_function()
--!     return 1 + 1
--! end
--! 
--! local function loop(std, game)
--!     if std.key.press.a then
--!         local result = std.mem.cache('slow-function', slow_function)
--!         std.draw.text(result)
--!     end
--! end
--! @endcode
local function cache(key, load_func, unload_func)
    local value = cache_get(key)
    if value == nil then
        cache_set(key, load_func, unload_func)
        value = cache_get(key)
    end    
    return value
end

--! @par Example
--! @code
--! local function slow_function()
--!     return 1 + 1
--! end
--! 
--! local function loop(std, game)
--!     if std.key.press.b then
--!         std.mem.unset('slow-function')
--!     end
--! end
--! @endcode
local function unset(key)
    if memory_dict_unload[key] then
        memory_dict_unload[key](memory_dict[key])
    end
    memory_dict[key] = nil
end

--! @warning <b>Do not use it frequently</b> as @c loop() or @c draw(),
--! but at strategic points such as changing games or world.
--! This will clear all allocated memory, such as images, fonts, audios and things defined by you.
--! @par Example
--! @code
--! local function load_game(url)
--!     std.http.get(url)
--!         :success(function(std, game)
--!             std.mem.gc_clear_all()
--!             game.application = std.node.load(std.http.body)
--!             std.node.spawn(game.application)
--!         end)
--!         :run()
--! end
--! @endcode
local function gc_clear_all()
    local index = 1
    local items = #memory_list
    
    while index <= items do
        unset(memory_list[index])
        index = index + 1
    end
    
    memory_list = {}

    return items
end

--! @}
--! @}

local function install(std)
    std = std or {}
    std.mem = std.mem or {}
    std.mem.cache = cache
    std.mem.cache_get = cache_get
    std.mem.cache_set = cache_set
    std.mem.unset = unset
    std.mem.gc_clear_all = gc_clear_all

    return {
        mem=std.mem
    }
end

local P = {
    install=install
}

return P
