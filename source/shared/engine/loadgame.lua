local eval_file = require('source/shared/string/eval/file')
local eval_code = require('source/shared/string/eval/code')

local has_love_fs = love and love.filesystem and love.filesystem.getSource
local has_io_open = io and io.open

local function normalize(app, base)
    if not app then return nil end
    if not app.callbacks then
        local old_app = app
        app = {meta={},config={},callbacks={}, data={}}
        
        for key, value in pairs(old_app) do
            local is_function = type(value) == 'function'
            if base.meta and base.meta[key] and not is_function then
                app.meta[key] = value
            elseif base.config and base.config[key] and not is_function then
                app.config[key] = value
            elseif is_function then
                app.callbacks[key] = value
            else
                app.data[key] = value
            end
        end
    end

    local function defaults(a, b, key)
        if type(a[key]) ~= "table" then a[key] = {} end
        for k, v in pairs(b[key]) do
            if a[key][k] == nil then
                a[key][k] = b[key][k]
            end
        end
    end

    for field in pairs(base) do
        defaults(app, base, field)
    end

    return app
end

local function script(src, base)
    if type(src) == 'table' or type(src) == 'userdata' then
        return normalize(src, base)
    end

    local cwd = '.'
    local application = type(src) == 'function' and src
    
    if not src or #src == 0 then
        src = 'game'
    end

    if has_love_fs then
        cwd = love.filesystem.getSource()
    end

    if not application and src and src:find('\n') then
        local ok, app = eval_code.script(src)
        application = ok and app
    else
        local ok, app = eval_file.script(src)
        application = ok and app
    end

    if not application and has_io_open then
        local app_file = io.open(src)
        if app_file then
            local app_src = app_file:read('*a')
            local ok, app = eval_code.script(app_src)
            application = ok and app
            app_file:close()
        end
    end

    return normalize(application, base)
end

local P = {
    script = script
}

return P
