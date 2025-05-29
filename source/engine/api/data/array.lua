local util_decorator = require('src/lib/util/decorator')

--! @defgroup std
--! @{
--! @defgroup array
--! @{
--! @todo more examples in `std.array`
--! @page Pipeline
--! get the final array with `:array()` or `:json()`
--!
--! @code
--! local original_array = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
--! local modified_array = std.array.from(original_array)
--!    :filter(function(value) return value % 2 == 0 end)
--!    :map(function(value) return value * 2 end)
--!    :unique()
--!    :table()
--! @endcode

--! @short std.array.map
--! @renamefunc map
--! @param [in] array
--! @param [in] func
--! @return new array
local function array_map(array, func)
    local res = {}
    local index = 1
    local length = #array
    while index <= length do
        res[#res + 1] = func(array[index], index)
        index = index + 1
    end
    return res
end

--! @short std.array.filter
--! @renamefunc filter
--! @param [in] array
--! @param [in] func
--! @return new array
local function array_filter(array, func)
    func = func or (function(v) return v and v ~= 0 end)
    local res = {}
    local index = 1
    local length = #array
    while index <= length do
        local value = array[index]
        if func(value, index) then
            res[#res + 1] = value
        end
        index = index + 1
    end
    return res
end

--! @short std.array.unique
--! @renamefunc unique
--! @param [in] array
--! @return new array
local function array_unique(array)
    local res = {}
    local index = 1
    local length = #array
    local setmap = {}
    while index <= length do
        local value = array[index]
        if not setmap[value] then
            res[#res + 1] = value
        end
        setmap[value] = true
        index = index + 1
    end
    return res
end

--! @short std.array.each
--! @renamefunc each
--! @param [in] array
--! @param [in] func
local function array_foreach(array, func)
    local index = 1
    local length = #array
    while index <= length do
        func(array[index], index)
        index = index + 1
    end
end

--! @short std.array.reducer
--! @renamefunc reducer
--! @param [in] array
--! @param [in] func
--! @return some value
local function array_reducer(array, func, value)
    local index = value and 1 or 2
    local length = #array
    value = value or array[1]
    while index <= length do
        value = func(value, array[index], index)
        index = index + 1
    end
    return value
end

--! @short std.array.index
--! @renamefunc index
--! @param [in] array
--! @param [in] func
--! @return index of array
local function array_index(array, func, reverse)
    func = func or function() return true end
    local index, inc, final = 1, 1, #array

    if reverse then
        index, inc, final = #array, -1, 1
    end

    repeat
        if func(array[index], index) then
            return index
        end
        index = index + inc
    until (reverse and index < final) or (not reverse and index > final)
    
    return nil
end

--! @short std.array.first
--! @renamefunc first
--! @param [in] array
--! @param [in] func
--! @return value from array
local function array_first(array, func)
    local index = array_index(array, func)
    if index then
        return array[index]
    end
    return nil
end

--! @short std.array.last
--! @renamefunc first
--! @param [in] array
--! @param [in] func
--! @return value from array
local function array_last(array, func)
    local index = array_index(array, func, true)
    if index then
        return array[index]
    end
    return nil
end

--! @short std.array.some
--! @renamefunc some
--! @param [in] array
--! @param [in] func
--! @return boolean
local function array_some(array, func, reverse)
    local index, inc, final = 1, 1, #array

    if reverse then
        index, inc, final = #array, -1, 1
    end

    repeat
        if func(array[index], index) then
            return true
        end
        index = index + inc
    until (reverse and index < final) or (not reverse and index > final)
    
    return false
end

--! @short std.array.every
--! @renamefunc every
--! @param [in] array
--! @param [in] func
--! @return boolean
local function array_every(array, func)
    local index = 1
    local length = #array


    while index <= length do
        if not func(array[index], index) then
            return false
        end
        index = index + 1
    end
    
    return true
end

--! @cond
local function array_pipeline(std, array)
    
    local decorator_iterator = function(func) 
        return function(self, func2, extra)
            self.array = func(self.array, func2, extra)
            return self
        end
    end

    local decorator_reduce = function(func, return_self)
        return function(self, func2, extra)
            local res = func(self.array, func2, extra)
            return (return_self and self) or res
        end
    end

    local self = {
        array = array,
        map = decorator_iterator(array_map),
        filter = decorator_iterator(array_filter),
        unique = decorator_iterator(array_unique),
        each = decorator_reduce(array_foreach, true),
        reducer = decorator_reduce(array_reducer),
        index = decorator_reduce(array_index),
        first = decorator_reduce(array_first),
        last = decorator_reduce(array_last),
        some = decorator_reduce(array_some),
        every = decorator_reduce(array_every),
        table = function(self) return self.array end,
        json = function(self) return std.json.encode(self.array) end
    }

    return self
end
--! @endcond

--! @}
--! @}

local function install(std, engine, library, name)
    local lib = std[name] or {}
    lib.map = array_map
    lib.filter = array_filter
    lib.unique = array_unique
    lib.each = array_foreach
    lib.reducer = array_reducer
    lib.index = array_index
    lib.first = array_first
    lib.last = array_last
    lib.some = array_some
    lib.every = array_every
    lib.from = util_decorator.prefix1(std, array_pipeline)
    std[name] = lib
end

local P = {
    install = install
}

return P
