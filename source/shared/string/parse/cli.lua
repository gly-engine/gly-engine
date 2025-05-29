local zeebo_args = require('src/lib/common/args')

local function add_next_value(self, param, opt)
    local index = #self.param_list_value[self.current]
    self.param_list_value[self.current][index + 1] = param
    self.param_dict_value_alias[self.current][param] = opt.alias
    self.param_dict_value_default[self.current][param] = opt.default
    self.param_dict_value_required[self.current][param] = opt.required == true
    return self
end

local function add_option_get(self, param, opt)
    local index = #self.param_list_option_get[self.current]
    self.hidden[self.current][param] = opt.hidden == true
    self.param_list_option_get[self.current][index + 1] = param 
    self.param_dict_option_get_alias[self.current][param] = opt.alias
    self.param_dict_option_get_default[self.current][param] = opt.default
    self.param_dict_option_get_required[self.current][param] = opt.required == true
    return self
end

local function add_option_has(self, param, opt)
    local index = #self.param_list_option_has[self.current]
    self.param_list_option_has[self.current][index + 1] = param
    self.hidden[self.current][param] = opt.hidden == true
    return self
end

local function add_subcommand(self, cmd_name, cmd_collection)
    self.param_dict_option_get_required[cmd_name] = {}
    self.param_dict_option_get_default[cmd_name] = {}
    self.param_dict_option_get_alias[cmd_name] = {}
    self.param_list_option_get[cmd_name] = {}
    self.param_list_option_has[cmd_name] = {}
    self.param_dict_value_required[cmd_name] = {}
    self.param_dict_value_default[cmd_name] = {}
    self.param_dict_value_alias[cmd_name] = {}
    self.param_list_value[cmd_name] = {}
    self.hidden[cmd_name] = {}
    self.cmd_execution[cmd_name] = cmd_collection[cmd_name]
    self.commands[#self.commands + 1] = cmd_name
    self.current = cmd_name
    return self
end

local function run(self, host_args)
    if not host_args then 
        return true
    end

    local command = host_args[1]
    local args = {
        [0] = host_args[0],
        command = command
    }

    if not command then
        command = self.help
    end

    if not self.cmd_execution[command] then
        command = self.error_not_found
    end

    do
        local index = 1
        while index <= #self.param_list_option_has[command] do
            local param = self.param_list_option_has[command][index]
            args[param] = zeebo_args.has(host_args, param)
            index = index + 1
        end
    end
    
    do
        local index = 1
        while index <= #self.param_list_option_get[command] and command ~= self.error_usage do
            local param = self.param_list_option_get[command][index]
            local value = zeebo_args.get(host_args, param)
            local alias = self.param_dict_option_get_alias[command][param]
            local required = self.param_dict_option_get_required[command][param]
            local default_value = self.param_dict_option_get_default[command][param]
            if alias and (value or ''):sub(1, 1) == alias:sub(1, 1)  then
                value = alias:sub(2):gsub('{{'..param..'}}', value:sub(2))
            end
            if required and not value then
                command = self.error_usage
            end
            args[param] = value or default_value
            index = index + 1
        end
    end

    do
        local index = 1
        while index <= #self.param_list_value[command] and command ~= self.error_usage do
            local param = self.param_list_value[command][index]
            local value = zeebo_args.param(host_args, self.param_list_option_get[command], index + 1)
            local alias = self.param_dict_value_alias[command][param]
            local required = self.param_dict_value_required[command][param]
            local default_value = self.param_dict_value_default[command][param]
            if alias and (value or ''):sub(1, 1) == alias:sub(1, 1)  then
                value = self.param_dict_value_alias[command][param]:sub(2):gsub('{{'..param..'}}', value:sub(2))
            end
            if required and not value then
                command = self.error_usage
            end
            args[param] = value or default_value
            index = index + 1
        end
    end

    local usage = command == self.help and args[self.param_list_value[command][1]]
    if usage then
        args.command = usage
        if self.cmd_execution[usage] then
            command = self.error_usage
        else
            command = self.error_not_found
        end
    end

    if command == self.error_usage then
        args.params = self.param_list_value[args.command]
        args.hidden = self.hidden[args.command] or {}
        args.option_get = self.param_list_option_get[args.command]
        args.option_has = self.param_list_option_has[args.command]
    end

    return self.cmd_execution[command](args)
end

local function from(host_args)
    local cmd = {
        help = 'help',
        hidden = {},
        error_usage = nil,
        error_not_found = nil,
        param_dict_option_get_required = {},
        param_dict_option_get_default = {},
        param_dict_option_get_alias = {},
        param_list_option_get = {},
        param_list_option_has = {},
        param_dict_value_required = {},
        param_dict_value_default = {},
        param_dict_value_alias = {},
        param_list_value = {},
        cmd_execution = {},
        commands = {},
        current = nil
    }

    cmd.add_next_value = function(param, opt)
        return add_next_value(cmd, param, opt or {})
    end

    cmd.add_option_get = function(param, opt)
        return add_option_get(cmd, param, opt or {})
    end

    cmd.add_option_has = function(param, opt)
        return add_option_has(cmd, param, opt or {})
    end

    cmd.add_subcommand = function(cmd_name, cmd_collection)
        return add_subcommand(cmd, cmd_name, cmd_collection)
    end

    cmd.add_help_subcommand = function(cmd_name, cmd_collection)
        cmd.help = cmd_name
        return add_subcommand(cmd, cmd_name, cmd_collection)
    end

    cmd.add_error_cmd_usage = function(cmd_name, cmd_collection)
        cmd.error_usage = cmd_name
        return add_subcommand(cmd, cmd_name, cmd_collection)
    end

    cmd.add_error_cmd_not_found = function(cmd_name, cmd_collection)
        cmd.error_not_found = cmd_name
        return add_subcommand(cmd, cmd_name, cmd_collection)
    end

    cmd.run = function()
        return run(cmd, host_args)
    end

    return cmd
end

local P = {
    from=from
}

return P
