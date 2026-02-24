local json = require('source/third_party/rxi_json')

local cli2 = {}

function cli2.load_cmds(path)
    local f = io.open(path or 'cmds.json', 'r')
    if not f then error('Could not open ' .. (path or 'cmds.json')) end
    local content = f:read('*a')
    f:close()
    return json.decode(content)
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

function cli2.list(cmds)
    local width = get_width(cmds)
    local lines = {}
    for _, cmd in ipairs(cmds) do
        if not cmd.hidden then
            table.insert(lines, string.format('  %-' .. width .. 's  %s', cmd.name, cmd.description or ''))
        end
    end
    return table.concat(lines, '\n')
end

local function render_section(title, items, formatter)
    if not items or #items == 0 then return "" end
    local lines = { title .. ':' }
    local has_content = false
    for _, item in ipairs(items) do
        local line = formatter(item)
        if line then 
            table.insert(lines, '  ' .. line) 
            has_content = true
        end
    end
    if not has_content then return "" end
    return table.concat(lines, '\n') .. '\n\n'
end

function cli2.render_help(cmd, display_name, all_classes)
    local out = 'Usage: gly ' .. display_name .. ' [options]\n\n'
    out = out .. 'Description:\n  ' .. (cmd.description or 'No description') .. '\n\n'

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

    local fmt = '%-' .. label_w .. 's  %s'
    local try_cmd = nil

    -- Related Targets
    out = out .. render_section('Related Targets', related, function(r)
        return string.format(fmt, r.name, r.description or '')
    end)

    -- Arguments
    out = out .. render_section('Arguments', cmd.args, function(arg)
        local desc = arg.description or ''
        if arg.required then desc = desc .. ' (required)' end
        return string.format(fmt, arg.name, desc)
    end)

    -- Flags
    out = out .. render_section('Flags', cmd.flags, function(flag)
        if cmd.values and cmd.values[flag.name] ~= nil then return nil end
        
        local label = '--' .. flag.name
        local desc = (flag.description or '') .. (flag.type and (' (' .. flag.type .. ')') or '') .. (flag.default and (' [default: ' .. tostring(flag.default) .. ']') or '')
        local line = string.format(fmt, label, desc)
        
        if flag.type == 'enum' and flag.classes then
            line = line .. '\n      Available ' .. flag.name .. 's:'
            local cmd_base = display_name:match('^%S+') or display_name
            for _, class in ipairs(flag.classes) do
                if not class.variant and not class.alias then
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
                    local v_str = #variants > 0 and (" (variants: " .. table.concat(variants, ", ") .. ")") or ""
                    line = line .. string.format('\n        %-10s %s%s', class.name, class.description or '', v_str)
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

local function evaluate_rules(state, rules)
    for _, rule in ipairs(rules) do
        local op, key, val = rule[1], rule[2], rule[3]
        local actual = state[key]
        if actual == nil then actual = "false" end
        
        local actual_str = tostring(actual)
        local val_str = tostring(val)
        local actual_num = tonumber(actual)
        local val_num = tonumber(val)

        local matched = false
        if op == "eq" or op == "==" then matched = (actual_str == val_str)
        elseif op == "neq" or op == "!=" then matched = (actual_str ~= val_str)
        elseif op == "gt" or op == ">" then matched = (actual_num and val_num and actual_num > val_num)
        elseif op == "gte" or op == ">=" then matched = (actual_num and val_num and actual_num >= val_num)
        elseif op == "lt" or op == "<" then matched = (actual_num and val_num and actual_num < val_num)
        elseif op == "lte" or op == "<=" then matched = (actual_num and val_num and actual_num <= val_num)
        elseif op == "like" then matched = (actual_str:find(val_str) ~= nil)
        end
        if not matched then return false end
    end
    return true
end

function cli2.parse(arg)
    local data = cli2.load_cmds()
    local cmds = data.commands
    local input = arg[1]

    if not input or input == 'help' then
        print(cli2.get_help(cmds, arg[2], arg[3]))
        return
    end

    local matches = {}
    for _, c in ipairs(cmds) do
        if c.name == input then matches = {c} break end
        if c.name:sub(1, #input) == input then table.insert(matches, c) end
    end

    if #matches == 0 then
        print('Error:\nUnknown command "' .. input .. '"\n\nTry:\n\ngly help\n')
        return
    elseif #matches > 1 then
        print('Ambiguous command "' .. input .. '". Matches:')
        for _, m in ipairs(matches) do print('  ' .. m.name) end
        return
    end

    local base_cmd = matches[1]
    local active_cmd = base_cmd
    local state = {}
    local active_help_path = base_cmd.name
    local errors = {}

    -- 1. Defaults
    for _, f in ipairs(base_cmd.flags or {}) do if f.default ~= nil then state[f.name] = f.default end end

    -- 2. First Pass: Context Resolution (Core/Class)
    for i = 2, #arg do
        local val = arg[i]
        local k, v = val:match("^%-%-([^=]+)=(.*)$")
        if not k and val:sub(1,2) == '--' then k = val:sub(3) v = arg[i+1] end
        
        local class, flag_name = _find_class(base_cmd, v or val)
        if class then
            active_cmd = class
            active_help_path = base_cmd.name .. " " .. (v or val)
            state[flag_name] = v or val
            for _, f in ipairs(class.flags or {}) do if f.default ~= nil then state[f.name] = f.default end end
            for vk, vv in pairs(class.values or {}) do state[vk] = vv end
            break
        end
    end

    -- 3. Second Pass: State Mapping & Type Validation
    local positional_idx = 0
    local skip_next = false
    for i = 2, #arg do
        if skip_next then
            skip_next = false
        else
            local val = arg[i]
            if val:sub(1, 2) == '--' then
                local k, v = val:match("^%-%-([^=]+)=(.*)$")
                local has_assign = (k ~= nil)
                if not k then k = val:sub(3) end
                
                -- Find flag in active context or base
                local flag_def
                for _, f in ipairs(active_cmd.flags or {}) do if f.name == k then flag_def = f break end end
                if not flag_def and active_cmd ~= base_cmd then
                    for _, f in ipairs(base_cmd.flags or {}) do if f.name == k then flag_def = f break end end
                end
                
                if flag_def then
                    local current_val = v
                    local consumed_next = false
                    if not has_assign and flag_def.type ~= 'boolean' then
                        current_val = arg[i+1]
                        if current_val and current_val:sub(1,1) ~= '-' then
                            consumed_next = true
                        else
                            current_val = "true" -- Fallback
                        end
                    end

                    -- Enum Validation
                    if flag_def.type == 'enum' then
                        if not _find_class_in_flag(flag_def, current_val) then
                            table.insert(errors, "Invalid value for --" .. k .. ": " .. tostring(current_val))
                        end
                    end

                    state[k] = current_val
                    if consumed_next then skip_next = true end
                else
                    table.insert(errors, 'Unknown option: ' .. val)
                end
            elseif val:sub(1, 1) ~= '-' then
                positional_idx = positional_idx + 1
                local arg_def = base_cmd.args and base_cmd.args[positional_idx]
                if arg_def then state[arg_def.name] = val end
            end
        end
    end

    -- 4. Final Validations
    if base_cmd.args then
        local req_count = 0
        for _, a in ipairs(base_cmd.args) do if a.required then req_count = req_count + 1 end end
        if positional_idx < req_count then table.insert(errors, 'Missing required arguments')
        elseif positional_idx > #base_cmd.args then table.insert(errors, 'Too many arguments') end
    end

    if data.errors then
        for _, rule in ipairs(data.errors) do
            if evaluate_rules(state, rule.when) then table.insert(errors, rule.message) end
        end
    end

    -- 5. Reporting
    if #errors > 0 then
        print('Error:')
        for _, err in ipairs(errors) do print(err) end
        print('\nTry:\n\ngly help ' .. active_help_path .. "\n")
        return
    end

    if base_cmd.name ~= input then
        print('Partial match: ' .. base_cmd.name .. '\n')
        print(cli2.get_help(cmds, base_cmd.name))
        return
    end

    print('Command "' .. base_cmd.name .. '" validated. State:')
    local sorted_keys = {}
    for k in pairs(state) do table.insert(sorted_keys, k) end
    table.sort(sorted_keys)
    for _, k in ipairs(sorted_keys) do print("  " .. k .. ": " .. tostring(state[k])) end
end

return cli2
