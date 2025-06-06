local function get_ext(self)
    return function()
        return self.extension
    end
end

local function get_file(self)
    return function()
        if self.extension and #self.extension > 0 then
            return self.filename..'.'..self.extension
        end
        return self.filename
    end
end

local function get_filename(self)
    return function()
        return self.filename
    end
end

local function get_path(self, separator)
    return function()
        local index = 1
        local content = self.absolute and separator or ''
        if self.absolute and separator == '\\' then
            content = self.windriver..':'..content
        end
        if not self.absolute and self.path[index] == '.' then
            index = index + 1
        end
        while index <= #self.path do
            content = content..self.path[index]..separator
            index = index + 1
        end
        return content
    end
end

local function get_fullfilepath(self, separator)
    return function()
        return get_path(self, separator)()..get_file(self)()
    end
end

local function luapath(func)
    return function(src)
        if src then
            return func(src
                :gsub('^%./', '')
                :gsub('^%.\\', '')
                :gsub('%.', '/')
                :gsub('%.lua$', '')
                ..'.lua'
            )
        end
        return nil
    end
end

local function scan(type_file)
    return function(src, src2)
        src = (src or ''):gsub('%s*$', '')
        if #src == 0 then return nil end

        local hasfile = type_file
        local firstchar = src:sub(1,1)
        local secondchar = src:sub(2,2)
        local windriver = string.match(src, '^([A-Z]):[/\\]')
        local separator = (mock_separator or (_G.package and _G.package.config) or '/'):sub(1,1)

        local self = {
            windriver= 'WINDOWS',
            absolute = false,
            extension='',
            filename='',
            path={}
        }

        if firstchar == '/' or firstchar == '\\' or windriver then
            self.windriver = windriver or 'C'
            self.absolute = true
        elseif firstchar ~= '.' and secondchar ~= '/' then
            src = '.'..separator..src
        end

        if windriver then
            src = src:sub(3)
        end

        src:gsub("([^/\\]+)", function(part)
            self.path[#self.path + 1] = part
        end)

        if not type_file and src2 then
            self.path[#self.path + 1] = src2
            hasfile = true
        end

        if hasfile then
            self.filename, self.extension = self.path[#self.path]:match("^(.-)%.([^%.]+)$")
            self.filename = self.filename or self.path[#self.path]
            self.extension = self.extension or ''
            self.path[#self.path] = nil
        end

        return {
            get_ext=get_ext(self),
            get_file=get_file(self),
            get_filename=get_filename(self),
            get_sys_path=get_path(self, separator),
            get_win_path=get_path(self, '\\'),
            get_unix_path=get_path(self, '/'),
            get_fullfilepath=get_fullfilepath(self, separator)
        }
    end
end

local P = {
    file = scan(true),
    path = scan(false),
    lua = luapath(scan(true))
}

return P
