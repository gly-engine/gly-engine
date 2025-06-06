--! @bootstrap
local function file_reader(self, mode, size, func)
    if not self.content or #self.content == 0 then
        self.content = func()
    end

    if self.pointer >= #self.content then
        return nil
    elseif size == '*a' then
        return self.content
    elseif size == nil then
        local content = self.content
        local line_index = content:find('\n', self.pointer)
        if line_index then
            local line = content:sub(self.pointer, line_index)
            self.pointer = self.pointer + #line
            return line
        else
            local line = content:sub(self.pointer)
            self.pointer = self.pointer + #line
            return line
        end
    elseif type(size) == 'number' then
        local content = self.content:sub(self.pointer, self.pointer + size)
        self.pointer = self.pointer + #content
        return content
    else
        error("not implemented: "..tostring(size))
    end
end
--! @endbootstrap

local function popen(commands)
    return function(command)
        assert(commands[command] ~= nil, command:gsub('\n', '\\n'))
        return commands[command]
    end
end

local function open(files)
    local storage = {}
    return function (filename, mode)
        filename = filename:gsub('^%./', '')
        if (mode or 'r'):find('r') and (files[filename] or storage[filename]) then
            return {
                pointer = 1,
                write = function() end,
                close = function() end,
                read = function(self, size)
                    return file_reader(self, mode, size, function()
                        return files[filename] or storage[filename]
                    end)
                end
            }
        elseif mode == 'w' then
            return {
                content = '',
                write = function(self, c) self.content = self.content..c end,
                close = function(self) storage[filename] = self.content end
            }
        end
    end
end

local P = {
    popen = popen,
    open = open
}

return P
