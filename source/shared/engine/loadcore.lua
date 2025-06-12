local zeebo_pipeline = require('source/shared/functional/pipeline')
local requires = require('source/shared/string/dsl/requires')

local function step_install_libsys(self, lib_name, library, custom, is_system)
    if not is_system then return end
    local ok, msg = pcall(function()
        library.install(self.std, self.engine, custom, lib_name)
    end)
    if ok then
        self.libsys[lib_name] = true
    else
       self.error('sys', lib_name, msg)
    end
end

local function step_check_libsys(self, lib_name, library, custom, is_system)
    if not is_system then return end
    if not self.libsys[lib_name] then
       self.error('sys', lib_name, 'is missing!')
    end
end

local function step_install_libusr(self, lib_name, library, custom, is_system)
    if is_system then return end
    if self.libusr[lib_name] then return end
    if not requires.should_import(self.spec, lib_name) then return end

    self.libusr[lib_name] = pcall(function()
        library.install(self.std, self.engine, custom, lib_name)
    end)
end

local function step_check_libsys_all(self)
    local missing = requires.missing(self.spec, self.libusr)
    if #missing > 0 then
        self.error('usr', '*', 'missing libs: '..table.concat(missing, ' '))
    end
end

local function package(self, lib_name, library, custom)
    self.pipeline[#self.pipeline + 1] = function()
        local is_system = lib_name:sub(1, 1) == '@'
        local name = is_system and lib_name:sub(2) or lib_name
        self:step(name, library, custom, is_system)
    end

    return self
end

local function setup(std, application, engine)
    if not application then
        error('game not found!')
    end

    local spec = requires.encode((application.config or application).require or '')

    local self = {
        std = std,
        spec = spec,
        errmsg = '',
        engine = engine,
        package = package,
        -- checking
        libusr = {},
        libsys = {},
        -- internal
        pipeline = {},
        pipe = zeebo_pipeline.pipe
    }

    self.error = function (prefix, lib_name, message) 
        self.errmsg = self.errmsg..'['..prefix..':'..lib_name..'] '..message..'\n'
    end

    self.run = function()
        self.step = step_install_libsys
        zeebo_pipeline.reset(self)
        zeebo_pipeline.run(self)

        self.step = step_check_libsys
        zeebo_pipeline.reset(self)
        zeebo_pipeline.run(self)

        self.step = step_install_libusr
        zeebo_pipeline.reset(self)
        zeebo_pipeline.run(self)

        step_check_libsys_all(self)
        if #self.errmsg > 0 then
            error(self.errmsg, 0)
        end
    end

    return self
end

local P = {
    setup = setup
}

return P