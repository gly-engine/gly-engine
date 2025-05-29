local util_decorator = require('src/lib/util/decorator')
local os = require('os')

--! @defgroup std
--! @{

--! @todo getenv build variables
local function getenv(engine, varname)
    local game_envs = engine.root and engine.root.envs
    local core_envs = engine.envs
    if game_envs and game_envs[varname] then
        return game_envs[varname]
    end
    if core_envs and core_envs[varname] then
        return core_envs[varname]
    end    
    if os and os.getenv then
        return os.getenv(varname)
    end
    return nil
end

--! @}

local function install(std, engine)
    std.getenv = util_decorator.prefix1(engine, getenv)
end

local P = {
    install = install
}

return P
