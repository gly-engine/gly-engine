local function creater_counter(start)
    local next_id = start or 0
    local free = {}
    local free_top = 0

    local function nextId()
        if free_top > 0 then
            local id = free[free_top]
            free[free_top] = nil
            free_top = free_top - 1
            return id
        end

        next_id = next_id + 1
        return next_id
    end

    local function clearId(id)
        if id == nil then return end

        free_top = free_top + 1
        free[free_top] = id
    end

    local function clearAll(value)
        next_id = value or 0
        free = {}
        free_top = 0
    end

    return nextId, clearId, clearAll
end
