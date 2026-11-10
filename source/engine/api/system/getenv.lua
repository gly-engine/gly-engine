--! @defgroup std
--! @{

local function setenv(engine)
    return function(varname, value)
        if engine.root ~= engine.current then
            error('unauthorized set environment', 0)
        end
        if varname then
            engine.overrides_envs[varname] = value ~= nil and tostring(value) or nil
        end
    end
end

--! @todo getenv build variables
--! @return string, or nil when not defined, empty or only spaces
local function getenv(engine, get_env)
    return function(varname)
        if type(varname) ~= 'string' or #varname == 0 then
            return nil
        end

        local game_envs = engine.root and engine.root.envs
        local value = engine.overrides_envs[varname]

        if value == nil and game_envs then
            value = game_envs[varname]
        end
        if value == nil and engine.envs then
            value = engine.envs[varname]
        end
        if value == nil and get_env then
            value = get_env(varname)
        end
        if value == nil then
            return nil
        end

        value = tostring(value)
        if not value:find('%S') then
            return nil
        end
        return value
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
