local os = require('os')
local zeebo_module = require('source/shared/module')
local zeebo_bundler = require('source/cli/build/bundler')
local zeebo_builder = require('source/cli/build/builder')
local zeebo_assets = require('source/cli/tools/assets')
local cli_meta = require('source/cli/tools/meta')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')
local zeebo_pipeline = require('source/shared/functional/pipeline')

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
        local from = str_fs.file(options.src)
        local to = str_fs.path(self.args.outdir..self.bundler, options.as or from.get_file())
        assert(zeebo_builder.build(from.get_unix_path(), from.get_file(), to.get_unix_path(), to.get_file(), options.prefix or '', self.args))
    end

    if #self.bundler > 0 and options.src then 
        self.pipeline[#self.pipeline + 1] = function()
            local file = options.as or str_fs.file(options.src).get_file()
            assert(zeebo_bundler.build(self.args.outdir..self.bundler..file, self.args.outdir..file))
        end
    end

    if options.assets then
        self.pipeline[#self.pipeline + 1] = function()
            local var = cli_meta.metadata(self.args.outdir..'game.lua')
            if var then assert(zeebo_assets.build(var.assets.list, self.args.outdir)) end
        end
    end

    return self
end

local function add_file(self, file_in, options)
    self.pipeline[#self.pipeline + 1] = function()
        local from = str_fs.file(file_in)
        local to = str_fs.path(self.args.outdir, (options and options.as) or from.get_file())
        cli_fs.mkdir(to.get_sys_path())
        cli_fs.move(from.get_fullfilepath(), to.get_fullfilepath())
    end

    return self
end

local function add_meta(self, file_in, options)
    self.pipeline[#self.pipeline + 1] = function()
        local from = str_fs.file(file_in)
        local to = str_fs.path(self.args.outdir, (options and options.as) or from.get_file())
        local input = io.open(from.get_fullfilepath(), 'r')
        local output = io.open(to.get_fullfilepath(), 'w')
        local content = cli_meta.render(self.args.outdir..'game.lua', input:read('*a'), self.args, true)
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
