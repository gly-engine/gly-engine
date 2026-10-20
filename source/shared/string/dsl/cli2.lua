local json = require('source/third_party/rxi_json')

local cli2 = {}

local VALID_TYPES = {
    string = true, number = true, boolean = true, 
    file = true, enum = true, directory = true
}

local function validate_dsl(data)
    if type(data) ~= 'table' then return false, "DSL must be a table", nil end
    if not data.commands then return false, "DSL must have 'commands' list", nil end

    local function check_item(item, path)
        if not item.name then return false, path .. " is missing 'name'" end
        if not item.description and not item.hidden then 
            return false, path .. " (" .. item.name .. ") is missing 'description'" 
        end
        
        if item.args then
            for i, arg in ipairs(item.args) do
                local arg_path = path .. " arg[" .. i .. "]"
                if not arg.name then return false, arg_path .. " missing name" end
                if not arg.type then return false, arg_path .. " (" .. arg.name .. ") missing type" end
                if not VALID_TYPES[arg.type] then return false, arg_path .. " has invalid type: " .. arg.type end
                if not arg.description then return false, arg_path .. " missing description" end
            end
        end

        if item.flags then
            for i, flag in ipairs(item.flags) do
                local flag_path = path .. " flag[" .. i .. "]"
                if not flag.name then return false, flag_path .. " missing name" end
                if not flag.type then return false, flag_path .. " (" .. flag.name .. ") missing type" end
                if not VALID_TYPES[flag.type] then return false, flag_path .. " has invalid type: " .. flag.type end
                if not flag.description then return false, flag_path .. " missing description" end
                
                if flag.type == 'enum' and flag.classes then
                    for j, class in ipairs(flag.classes) do
                        local ok, err = check_item(class, flag_path .. " class[" .. j .. "]")
                        if not ok then return ok, err end
                    end
                end
            end
        end

        if item.subcommands then
            for i, sub in ipairs(item.subcommands) do
                local ok, err = check_item(sub, path .. " sub[" .. i .. "]")
                if not ok then return ok, err end
            end
        end

        return true
    end

    for i, cmd in ipairs(data.commands) do
        local ok, err = check_item(cmd, "command[" .. i .. "]")
        if not ok then return false, err, nil end
    end

    for i, global in ipairs(data.globals or {}) do
        if not global.name then return false, "global[" .. i .. "] missing name", nil end
        if type(global.redirect) ~= 'table' then return false, "global[" .. i .. "] (" .. global.name .. ") missing redirect", nil end
    end

    return true, "DSL validated successfully", data
end

function cli2.load_cmds(data)
    return validate_dsl(data)
end

local function copy_table(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[k] = copy_table(v) end
    return res
end

local function merge_flags(target, source)
    for _, sf in ipairs(source or {}) do
        local found = false
        for i, tf in ipairs(target) do
            if tf.name == sf.name then
                target[i] = copy_table(sf)
                found = true
                break
            end
        end
        if not found then table.insert(target, copy_table(sf)) end
    end
end

-- Resolve inheritance and aliases
local function resolve_class(cmd, class_item)
    local merged = { flags = {}, values = {}, args = copy_table(cmd.args) }
    
    local function find_base(name)
        for _, flag in ipairs(cmd.flags or {}) do
            if flag.classes then
                for _, c in ipairs(flag.classes) do
                    if c.name == name then return c end
                end
            end
        end
    end

    local base_name = class_item.alias
    if not base_name and class_item.variant then
        base_name = type(class_item.variant) == 'table' and class_item.variant[1] or class_item.variant
    end

    if base_name then
        local base = find_base(base_name)
        if base then
            local resolved_base = resolve_class(cmd, base)
            merged.description = resolved_base.description
            merge_flags(merged.flags, resolved_base.flags)
            for k, v in pairs(resolved_base.values or {}) do merged.values[k] = v end
        end
    end

    if type(class_item.variant) == 'table' and #class_item.variant > 1 then
        for i = 2, #class_item.variant do
            local v_name = class_item.variant[i]
            local base = find_base(v_name)
            if base then
                local resolved_base = resolve_class(cmd, base)
                merge_flags(merged.flags, resolved_base.flags)
                for k, v in pairs(resolved_base.values or {}) do merged.values[k] = v end
            end
        end
    end

    for k, v in pairs(class_item) do
        if k == "flags" then
            merge_flags(merged.flags, v)
        elseif k == "values" then
            for vk, vv in pairs(v) do merged.values[vk] = vv end
        elseif k ~= "variant" and k ~= "alias" and k ~= "args" then
            merged[k] = copy_table(v)
        end
    end
    
    return merged
end

local function get_width(items, key, extra)
    local max = 0
    for _, item in ipairs(items or {}) do
        if not item.hidden then 
            max = math.max(max, #(item[key or 'name'] or "") + (extra or 0)) 
        end
    end
    return math.max(max, 10)
end

local HELP_WIDTH = 80

--! word wrap at HELP_WIDTH, continuation lines start at column @c indent
local function wrap(text, indent, start)
    local lines, line, col = {}, '', start or indent
    for word in tostring(text):gmatch('%S+') do
        if #line > 0 and col + #line + 1 + #word > HELP_WIDTH then
            lines[#lines + 1] = line
            line, col = word, indent
        else
            line = #line > 0 and (line .. ' ' .. word) or word
        end
    end
    lines[#lines + 1] = line
    return (table.concat(lines, '\n' .. string.rep(' ', indent)):gsub('\1', ' '))
end

--! text never broken by @c wrap
local function nowrap(text)
    return (tostring(text):gsub(' ', '\1'))
end

--! label padded to @c width at column @c indent, followed by wrapped description
local function column(indent, label, width, desc)
    local head = string.rep(' ', indent) .. label .. string.rep(' ', width - #label) .. '  '
    return head .. wrap(desc or '', #head)
end

function cli2.list(cmds)
    local width = get_width(cmds)
    local lines = {}
    for _, cmd in ipairs(cmds) do
        if not cmd.hidden then
            table.insert(lines, column(2, cmd.name, width, cmd.description))
        end
    end
    return table.concat(lines, '\n')
end

local function render_section(title, items, formatter)
    if not items or #items == 0 then return "" end
    local lines = { title .. ':' }
    local has_content = false
    for _, item in ipairs(items) do
        local line = not item.hidden and formatter(item)
        if line then 
            table.insert(lines, line) 
            has_content = true
        end
    end
    if not has_content then return "" end
    return table.concat(lines, '\n') .. '\n\n'
end

function cli2.render_help(cmd, display_name, all_classes)
    local usage = cmd.subcommands and ' <subcommand> [options]' or ' [options]'
    local out = 'Usage: gly ' .. display_name .. usage .. '\n\n'
    out = out .. 'Description:\n  ' .. wrap(cmd.description or 'No description', 2) .. '\n\n'

    if cmd.subcommands then
        out = out .. 'Subcommands:\n' .. cli2.list(cmd.subcommands) .. '\n\n'
    end

    local label_w = 0
    local related = {}
    if all_classes then
        for _, c in ipairs(all_classes) do
            local is_rel = false
            if type(c.variant) == 'table' then
                for _, vn in ipairs(c.variant) do if vn == cmd.name then is_rel = true break end end
            elseif c.variant == cmd.name then is_rel = true end
            if c.alias == cmd.name then is_rel = true end
            if is_rel and c.name ~= cmd.name then table.insert(related, c) end
        end
    end

    label_w = math.max(label_w, get_width(related))
    label_w = math.max(label_w, get_width(cmd.args))
    label_w = math.max(label_w, get_width(cmd.flags, 'name', 2))

    local try_cmd = nil

    -- Related Targets
    out = out .. render_section('Related Targets', related, function(r)
        return column(2, r.name, label_w, r.description)
    end)

    -- Arguments
    out = out .. render_section('Arguments', cmd.args, function(arg)
        local desc = (arg.description or '') .. (arg.type and (' (' .. arg.type .. ')') or '')
        if arg.required then desc = desc .. ' (required)' end
        if arg.default ~= nil then desc = desc .. ' ' .. nowrap('[default: ' .. tostring(arg.default) .. ']') end
        return column(2, arg.name, label_w, desc)
    end)

    -- Flags
    out = out .. render_section('Flags', cmd.flags, function(flag)
        if cmd.values and cmd.values[flag.name] ~= nil then return nil end
        
        local label = '--' .. flag.name
        local default = flag.default
        for _, class in ipairs(flag.classes or {}) do
            if class.name == default and class.hidden then default = nil end
        end
        local desc = (flag.description or '') .. (flag.type and (' (' .. flag.type .. ')') or '') .. (default ~= nil and (' ' .. nowrap('[default: ' .. tostring(default) .. ']')) or '')
        local line = column(2, label, label_w, desc)
        
        if flag.type == 'enum' and flag.classes then
            line = line .. '\n      Available ' .. flag.name .. 's:'
            local cmd_base = display_name:match('^%S+') or display_name
            local class_w = get_width(flag.classes)
            for _, class in ipairs(flag.classes) do
                if not class.variant and not class.alias and not class.hidden then
                    local variants = {}
                    for _, v in ipairs(flag.classes) do
                        local is_v = false
                        if type(v.variant) == 'table' then
                            for _, vn in ipairs(v.variant) do if vn == class.name then is_v = true break end end
                        else
                            is_v = (v.variant == class.name)
                        end
                        if is_v then table.insert(variants, v.name) end
                    end
                    line = line .. '\n' .. column(8, class.name, class_w, class.description)
                    if #variants > 0 then
                        local indent = 8 + class_w + 2
                        line = line .. '\n' .. string.rep(' ', indent) .. wrap('(variants: ' .. table.concat(variants, ', ') .. ')', indent)
                    end
                    if not try_cmd then try_cmd = "gly help " .. cmd_base .. " " .. class.name end
                end
            end
        end
        return line
    end)

    -- Try section
    if try_cmd then
        out = out .. "Try:\n\n" .. try_cmd .. "\n"
    end

    return out:gsub('\n\n$', '\n')
end

local function _find_class(cmd, name)
    if not cmd.flags then return end
    for _, flag in ipairs(cmd.flags) do
        if flag.classes then
            for _, class in ipairs(flag.classes) do
                if class.name == name then 
                    return resolve_class(cmd, class), flag.name, flag.classes
                end
            end
        end
    end
end

local function _find_class_in_flag(flag, name)
    if not flag or not flag.classes then return end
    for _, class in ipairs(flag.classes) do
        if class.name == name then return class end
    end
end

local function evaluate_rules(state, rules)
    if not rules then return true end
    if type(rules[1]) == "string" then
        local op = rules[1]
        if op == "and" then
            for i = 2, #rules do if not evaluate_rules(state, rules[i]) then return false end end
            return true
        elseif op == "or" then
            for i = 2, #rules do if evaluate_rules(state, rules[i]) then return true end end
            return false
        end
    end

    local op, key, val = rules[1], rules[2], rules[3]
    local actual = state[key]
    if actual == nil then actual = false end
    
    local actual_str = tostring(actual)
    local val_str = tostring(val)
    local actual_num = tonumber(actual)
    local val_num = tonumber(val)

    if op == "eq" or op == "==" then return actual_str == val_str
    elseif op == "neq" or op == "!=" then return actual_str ~= val_str
    elseif op == "gt" or op == ">" then return (actual_num and val_num and actual_num > val_num)
    elseif op == "gte" or op == ">=" then return (actual_num and val_num and actual_num >= val_num)
    elseif op == "lt" or op == "<" then return (actual_num and val_num and actual_num < val_num)
    elseif op == "lte" or op == "<=" then return (actual_num and val_num and actual_num <= val_num)
    elseif op == "like" then return (actual_str:find(val_str) ~= nil)
    end
    return false
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function resolve_shortcut(data, state, name, val, item_type)
    if type(val) ~= 'string' or val:sub(1,1) ~= '@' or not data.shortcuts then
        return val
    end
    
    local raw = val:sub(2)
    local expected_sc_name = "@{" .. name .. "}"
    
    for _, sc in ipairs(data.shortcuts) do
        if sc.name == expected_sc_name then
            local key = sc.name:match("@{(%w+)}")
            local s_state = copy_table(state)
            if key then s_state[key] = raw end
            s_state[name] = raw
            
            if evaluate_rules(s_state, sc.when) then
                local fallback = nil
                for _, v in ipairs(sc.values) do
                    local res = v
                    if key then res = res:gsub("{{"..key.."}}", raw) end
                    res = res:gsub("{{"..name.."}}", raw)
                    
                    if item_type ~= "file" or file_exists(res) then
                        return res
                    end
                    if not fallback then fallback = res end
                end
                if fallback then return fallback end
            end
        end
    end
    return val
end

function cli2.get_help(cmds, name, sub_or_class)
    if not name or name == '' then
        return 'Usage: gly <command> [args] [flags]\n\nAvailable commands:\n' .. cli2.list(cmds)
    end

    local cmd
    for _, c in ipairs(cmds) do if c.name == name then cmd = c break end end
    if not cmd then return 'Unknown command: ' .. name end

    if not sub_or_class or sub_or_class == '' then
        return cli2.render_help(cmd, cmd.name)
    end

    local function _find_sub(c, n)
        for _, s in ipairs(c.subcommands or {}) do if s.name == n then return s end end
    end
    
    local target = _find_sub(cmd, sub_or_class)
    if target then return cli2.render_help(target, cmd.name .. ' ' .. target.name) end

    local class, flag, all_classes = _find_class(cmd, sub_or_class)
    if class then return cli2.render_help(class, cmd.name .. ' --' .. flag .. ' ' .. class.name, all_classes) end

    return 'Unknown subcommand or class "' .. sub_or_class .. '" for ' .. name
end

local function parse(data, cmds, arg, prefix)
    local input = arg[1]

    if #prefix == 0 and (not input or input == 'help') then
        return true, cli2.get_help(cmds, arg[2], arg[3]), {}
    end

    local matches = {}
    for _, c in ipairs(cmds) do
        if c.name == input then matches = {c} break end
        if c.name:sub(1, #input) == input then table.insert(matches, c) end
    end

    if #matches == 0 then
        return false, 'Error:\nUnknown command "' .. prefix .. input .. '"\n\nTry:\n\ngly help ' .. prefix .. '\n', {}
    elseif #matches > 1 then
        local lines = {'Ambiguous command "' .. prefix .. input .. '". Matches:'}
        for _, m in ipairs(matches) do table.insert(lines, '  ' .. prefix .. m.name) end
        return false, table.concat(lines, '\n'), {}
    end

    local base_cmd = matches[1]

    if base_cmd.subcommands then
        local path = prefix .. base_cmd.name
        if not arg[2] then
            return true, cli2.render_help(base_cmd, path), {}
        end
        local rest = {}
        for i = 2, #arg do rest[#rest + 1] = arg[i] end
        local ok, out, state = parse(data, base_cmd.subcommands, rest, path .. ' ')
        if state.command then
            state.subcommand = state.command
            state.command = base_cmd.name
        end
        return ok, out, state
    end

    local active_cmd = base_cmd
    local state = { command = base_cmd.name }
    local active_help_path = prefix .. base_cmd.name
    local errors = {}

    -- Pass 1: Active Target Identification
    for i = 2, #arg do
        local val = arg[i]
        local k, v = val:match("^%-%-([^=]+)=(.*)$")
        if not k and val:sub(1,2) == '--' then k = val:sub(3) v = arg[i+1] end
        local class, flag_name = _find_class(base_cmd, v or val)
        if class then
            active_cmd = class
            active_help_path = prefix .. base_cmd.name .. " " .. (v or val)
            state[flag_name or 'core'] = v or val
            break
        end
    end

    -- Pipeline: 1. Populate Defaults
    local function populate_defaults(target_cmd)
        if not target_cmd.flags then return end
        for _, f in ipairs(target_cmd.flags) do
            if f.default ~= nil and state[f.name] == nil then
                state[f.name] = f.default
            elseif f.type == 'boolean' and state[f.name] == nil then
                state[f.name] = false
            end
        end
    end
    populate_defaults(base_cmd)
    if active_cmd ~= base_cmd then populate_defaults(active_cmd) end

    -- Pipeline: 2. Apply Fixed Values
    if active_cmd.values then
        for k, v in pairs(active_cmd.values) do state[k] = v end
    end

    -- Pass 2: User Inputs (Mapping)
    local positional_idx = 1
    local skip_next = false
    local user_inputs = {} -- Store raw inputs to resolve shortcuts later

    for i = 2, #arg do
        if skip_next then
            skip_next = false
        else
            local val = arg[i]
            if val:sub(1, 2) == '--' then
                local k, v = val:match("^%-%-([^=]+)=(.*)$")
                local has_assign = (k ~= nil)
                if not k then k = val:sub(3) end
                
                local flag_def
                for _, f in ipairs(active_cmd.flags or {}) do if f.name == k then flag_def = f break end end
                if not flag_def and active_cmd ~= base_cmd then
                    for _, f in ipairs(base_cmd.flags or {}) do if f.name == k then flag_def = f break end end
                end

                if flag_def and active_cmd.values and active_cmd.values[k] ~= nil then
                    flag_def = nil -- Treat as unknown if value is fixed
                end
                
                if flag_def then
                    local current_val = v
                    local consumed_next = false
                    
                    if not has_assign then
                        if flag_def.type == 'boolean' then
                            current_val = true
                        else
                            local next_arg = arg[i+1]
                            if next_arg and next_arg:sub(1,1) ~= '-' then
                                current_val = next_arg
                                consumed_next = true
                            else
                                current_val = true
                            end
                        end
                    end

                    -- Type conversion
                    if flag_def.type == 'boolean' then
                        if type(current_val) == 'string' then
                            current_val = (current_val ~= 'false')
                        end
                    elseif flag_def.type == 'number' then
                        if type(current_val) == 'string' then
                            current_val = tonumber(current_val) or current_val
                        end
                    end

                    if flag_def.type == 'enum' and not _find_class_in_flag(flag_def, current_val) then
                        table.insert(errors, "Invalid value for --" .. k .. ": " .. tostring(current_val))
                    end
                    state[k] = current_val
                    if consumed_next then skip_next = true end
                else
                    table.insert(errors, 'Unknown option: ' .. val)
                end
            elseif val:sub(1, 1) ~= '-' then
                local arg_def = base_cmd.args and base_cmd.args[positional_idx]
                if arg_def then
                    if arg_def.multiple or arg_def.array then
                        if type(state[arg_def.name]) ~= 'table' then 
                            state[arg_def.name] = {} 
                        end
                        table.insert(state[arg_def.name], val)
                    else
                        state[arg_def.name] = val
                        positional_idx = positional_idx + 1
                    end
                else
                    table.insert(errors, 'Too many arguments: ' .. val)
                end
            else
                table.insert(errors, 'Unknown option: ' .. val)
            end
        end
    end

    -- Pipeline: 3. Resolve Shortcuts
    local function resolve_all_shortcuts(definitions)
        for _, def in ipairs(definitions or {}) do
            local current = state[def.name]
            if type(current) == 'table' then
                for idx, v in ipairs(current) do
                    current[idx] = resolve_shortcut(data, state, def.name, v, def.type)
                end
            else
                state[def.name] = resolve_shortcut(data, state, def.name, current, def.type)
            end
        end
    end

    resolve_all_shortcuts(base_cmd.args)
    resolve_all_shortcuts(base_cmd.flags)
    if active_cmd ~= base_cmd then resolve_all_shortcuts(active_cmd.flags) end

    -- Required args check
    if base_cmd.args then
        local req_count = 0
        for _, a in ipairs(base_cmd.args) do if a.required then req_count = req_count + 1 end end
        local consumed = positional_idx - 1
        local last_arg = base_cmd.args[#base_cmd.args]
        if last_arg and (last_arg.multiple or last_arg.array) and type(state[last_arg.name]) == 'table' then
            consumed = consumed + #state[last_arg.name]
        end
        if consumed < req_count then table.insert(errors, 'Missing required arguments') end
    end

    -- Type Validation (File Existence), relative to --cwd when given
    local function exists(path)
        return file_exists(path) or (type(state.cwd) == 'string' and file_exists(state.cwd .. '/' .. path))
    end
    local function validate_types(definitions, values)
        for _, def in ipairs(definitions or {}) do
            local val = values[def.name]
            if val and def.type == "file" then
                if type(val) == "table" then
                    for _, v in ipairs(val) do
                        if not exists(v) then table.insert(errors, "File not found: " .. def.name .. " -> " .. v) end
                    end
                else
                    if not exists(val) then table.insert(errors, "File not found: " .. def.name .. " -> " .. val) end
                end
            end
        end
    end
    validate_types(base_cmd.args, state)
    validate_types(base_cmd.flags, state)
    if active_cmd ~= base_cmd then validate_types(active_cmd.flags, state) end

    if data.errors then
        for _, rule in ipairs(data.errors) do
            if evaluate_rules(state, rule.when) then table.insert(errors, rule.message) end
        end
    end

    if #errors > 0 then
        local out_err = {'Error:'}
        for _, err in ipairs(errors) do table.insert(out_err, err) end
        table.insert(out_err, '\nTry:\n\ngly help ' .. active_help_path .. "\n")
        return false, table.concat(out_err, '\n'), state
    end

    if base_cmd.name ~= input then
        local out_partial = {'Partial match: ' .. prefix .. base_cmd.name .. '\n'}
        table.insert(out_partial, cli2.render_help(base_cmd, prefix .. base_cmd.name))
        return true, table.concat(out_partial, '\n'), state
    end

    local out_final = {'Command "' .. prefix .. base_cmd.name .. '" validated. State:'}
    local sorted_keys = {}
    for k in pairs(state) do table.insert(sorted_keys, k) end
    table.sort(sorted_keys)
    for _, k in ipairs(sorted_keys) do
        local v = state[k]
        if type(v) == 'table' then
            table.insert(out_final, "  " .. k .. ": [" .. table.concat(v, ", ") .. "]")
        else
            table.insert(out_final, "  " .. k .. ": " .. tostring(v))
        end
    end
    return true, table.concat(out_final, '\n'), state
end

local function find_cmd(cmds, input)
    local found
    for _, c in ipairs(cmds or {}) do
        if c.name == input then return c end
        if input and c.name:sub(1, #input) == input then
            if found then return nil end
            found = c
        end
    end
    return found
end

--! subcommand or class (ex: @c --core html5) mentioned in the arguments
local function find_target(cmd, arg)
    if cmd.subcommands then
        local sub = find_cmd(cmd.subcommands, arg[2])
        return sub and sub.name
    end
    for i = 2, #arg do
        local value = arg[i]:match('^%-%-[^=]+=(.*)$') or arg[i]
        if _find_class(cmd, value) then return value end
    end
end

--! global flags replace the whole command line by its redirect
local function apply_globals(data, arg)
    for _, global in ipairs(data.globals or {}) do
        for _, val in ipairs(arg) do
            if val == '--' .. global.name or val == global.alias then
                local cmd = find_cmd(data.commands, arg[1])
                local vars = {
                    command = cmd and cmd.name,
                    target = cmd and find_target(cmd, arg)
                }
                local out = {}
                for _, item in ipairs(global.redirect) do
                    local res = item:gsub('{{(%w+)}}', function(key) return vars[key] or '' end)
                    if #res > 0 then out[#out + 1] = res end
                end
                return out
            end
        end
    end
    return arg
end

cli2.evaluate_rules = evaluate_rules

function cli2.parse(data, arg)
    return parse(data, data.commands, apply_globals(data, arg), '')
end

return cli2
