local os = require('os')

--! @defgroup std
--! @{

local function setenv(engine)
    return function(varname, value)
        if engine.root ~= engine.current then
            error('unauthorized set environment', 0)
        end
        if varname then
            engine.overrides_envs[varname] = tostring(value)
        end
    end
end

--! @todo getenv build variables
local function getenv(engine, get_env)
    return function(varname) 
        local game_envs = engine.root and engine.root.envs
        local core_envs = engine.envs
        
        if not (varname or #varname > 0) then
            return nil
        end
        if engine.overrides_envs[varname] then
            return engine.overrides_envs[varname]
        end
        if game_envs and game_envs[varname] then
            return game_envs[varname]
        end
        if core_envs and core_envs[varname] then
            return core_envs[varname]
        end    
        if get_env then
            return get_env(varname)
        end
        return nil
    end
end

--! @}

local function install(std, engine, cfg)
    engine.overrides_envs = {}
    std.getenv = getenv(engine, cfg.get_env)
    std.setenv = setenv(engine)
end

local P = {
    install = install
}

return P
