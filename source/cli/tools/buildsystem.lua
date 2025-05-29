local os = require('os')
local zeebo_pipeline = require('src/lib/util/pipeline')
local zeebo_module = require('src/lib/common/module')
local zeebo_bundler = require('src/lib/cli/bundler')
local zeebo_builder = require('src/lib/cli/builder')
local zeebo_assets = require('src/lib/cli/assets')
local zeebo_fs = require('src/lib/cli/fs')
local util_decorator = require('src/lib/util/decorator')
local util_fs = require('src/lib/util/fs')
local obj_ncl = require('src/lib/object/ncl')
local env_build = require('src/env/build')
local lustache = require('third_party/lustache/olivinelabs')

--! @todo move this function!
local function parser_assets(font_list, register_key, register_value)
    local index = 1
    local res = {}
    while index <= #font_list do
        local key, value = font_list[index]:match("([^:]+):(.+)")
        if key and value then
            res[#res + 1] = {
                [register_key] = key,
                [register_value] = value
            }
        end
        index = index + 1
    end
    return res
end

local function add_func(self, func, options)
    self.pipeline[#self.pipeline + 1] = function()
        local ok, msg = func()
        if not ok then error(msg or 'func error', 0) end
    end
    return self
end

local function add_step(self, command, options)
    self.pipeline[#self.pipeline + 1] = function()
        os.execute(command)
    end
    return self
end

local function add_core(self, core_name, options)
    if core_name ~= self.args.core then
        self.selected = false
        return self
    end
    options = options or {}
    options.src = (options.src and #options.src > 0) and options.src or nil

    self.found = true
    self.selected = true
    self.bundler = ''

    if options.force_bundler or self.args.bundler then
        self.bundler = '_bundler/'
    end
    
    self.pipeline[#self.pipeline + 1] = function()
        if not options.src then return end
        local from = util_fs.file(options.src)
        local to = util_fs.path(self.args.dist..self.bundler, options.as or from.get_file())
        assert(zeebo_builder.build(from.get_unix_path(), from.get_file(), to.get_unix_path(), to.get_file(), options.prefix or '', self.args))
    end

    if #self.bundler > 0 and options.src then 
        self.pipeline[#self.pipeline + 1] = function()
            local file = options.as or util_fs.file(options.src).get_file()
            assert(zeebo_bundler.build(self.args.dist..self.bundler..file, self.args.dist..file))
        end
    end

    if options.assets then
        self.pipeline[#self.pipeline + 1] = function()
            local game = zeebo_module.loadgame(self.args.dist..'game.lua')
            assert(zeebo_assets.build(game and game.assets or {}, self.args.dist))
        end
    end

    return self
end

local function add_file(self, file_in, options)
    self.pipeline[#self.pipeline + 1] = function()
        local from = util_fs.file(file_in)
        local to = util_fs.path(self.args.dist, (options and options.as) or from.get_file())
        zeebo_fs.mkdir(to.get_sys_path())
        zeebo_fs.move(from.get_fullfilepath(), to.get_fullfilepath())
    end

    return self
end

local function add_meta(self, file_in, options)
    self.pipeline[#self.pipeline + 1] = function()
        local from = util_fs.file(file_in)
        local to = util_fs.path(self.args.dist, (options and options.as) or from.get_file())
        local input = io.open(from.get_fullfilepath(), 'r')
        local output = io.open(to.get_fullfilepath(), 'w')
        local game_ok, game_app = pcall(zeebo_module.loadgame, self.args.dist..'game.lua')
        local meta = (game_ok and game_app and game_app.meta) or {}
        local content = lustache:render(input:read('*a'), {
            core={
                [self.args.core] = true
            },
            env={
                build=util_decorator.prefix1_t(self.args, env_build)
            },
            assets = {
                fonts = parser_assets(game_ok and game_app and game_app.fonts or {}, 'font', 'url')
            },
            ncl=obj_ncl,
            args=self.args,
            meta=meta
        })
        output:write(content)
        output:close()
        input:close()
    end
    return self
end

local function add_rule(self, error_message, ...)
    local arg_list = {...}
    self.pipeline[#self.pipeline + 1] = function()
        local index = 1
        while index <= #arg_list do
            local arg_name, arg_val = arg_list[index]:match('(%w+)=([%w_]+)')
            if tostring(self.args[arg_name]) ~= arg_val then
                error_message = nil
            end
            index = index + 1
        end
        if error_message then
            error(error_message, 0)
        end
    end
    return self
end

local function from(args)
    local decorator = function(func, for_all)
        return function(self, step, options)
            if not self.selected and not for_all then return self end
            if options and options.when ~= nil and not options.when then return self end
            return func(self, step, options)
        end        
    end

    local self = {
        args=args,
        found=false,
        selected=false,
        add_rule=add_rule,
        add_core=add_core,
        add_func=decorator(add_func),
        add_step=decorator(add_step),
        add_file=decorator(add_file),
        add_meta=decorator(add_meta),
        add_common_func=decorator(add_func, true),
        add_common_step=decorator(add_step, true),
        pipeline={}
    }

    self.run = function()
        if not self.found then
            return false, 'this core cannot be build!'
        end
        local success, message = pcall(zeebo_pipeline.run, self)
        return success, not success and message
    end

    return self
end

local P = {
    from=from
}

return P
