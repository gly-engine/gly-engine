local old_require = require

local function mock_require(decorators)
    return function(src)
        if decorators[src] then
            return decorators[src]()
        end
        return old_require(src)
    end
end

local P = {
    require=mock_require
}

return P