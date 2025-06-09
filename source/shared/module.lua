local zeebo_pipeline = require('source/shared/functional/pipeline')
local application_default = require('source/shared/var/object/root')

local function package(self, module_name, module, custom)
    local system = module_name:sub(1, 1) == '@'
    local name = system and module_name:sub(2) or module_name

    if system then
        self.list_append(name)
        self.stdlib_required[name] = true
    end

    self.pipeline[#self.pipeline + 1] = function ()
        if not self.list_exist(name) then return end
        if not system and not self.lib_required[name] then return end
        if not system and self.engine.lib_installed[name] then return end
        if system and self.engine.stdlib_installed[name] then return end
        
        local try_install = function()
            module.install(self.std, self.engine, custom, name)
            if module.event_bus then
                module.event_bus(self.std, self.engine, custom, name)
            end
        end
        
        local ok, msg = pcall(try_install)
        if not ok then
            self.lib_error[name] = msg    
            return
        end
        
        if system then
            self.engine.stdlib_installed[name] = true
        else
            self.engine.lib_installed[name] = true
        end
    end

    return self
end

local function require(std, application, engine)
    if not application then
        error('game not found!')
    end

    local application_require = application.config.require
    local next_library = application_require:gmatch('%S+')
    local self = {
        -- objects
        std=std,
        engine=engine,
        -- methods
        package = package,
        -- data
        event = {},
        list = {},
        lib_error = {},
        lib_optional = {},
        lib_required = {},
        stdlib_required = {},
        -- internal
        pipeline = {},
        pipe = zeebo_pipeline.pipe
    }

    if not engine.lib_installed then
        engine.lib_installed = {}
        engine.stdlib_installed = {}
    end

    self.list_exist = function (name)
        return self.lib_optional[name] or self.lib_required[name] or self.stdlib_required[name]
    end
    self.list_append = function (name)
        if not self.list_exist(name) then
            self.list[#self.list + 1] = name
        end
    end
    self.run = function()
        local index = 1
        zeebo_pipeline.run(self)
        while index <= #self.list do
            local name = self.list[index]
            if self.stdlib_required[name] and not self.engine.stdlib_installed[name] then
                error('system library not loaded: '..name..'\n'..(self.lib_error[name] or ''))
            end
            if self.lib_required[name] and not self.engine.lib_installed[name] then
                error('library not loaded: '..name..'\n'..(self.lib_error[name] or ''))
            end
            index = index + 1
        end
    end

    repeat
        local lib = next_library()
        if lib then
            local name, optional = lib:match('([%w%.]+)([?]?)')
            self.list_append(name)
            if optional and #optional > 0 then
                self.lib_optional[name] = true
            else
                self.lib_required[name] = true
            end
        end
    until not lib

    return self
end

local P = {
    require = require
}

return P
