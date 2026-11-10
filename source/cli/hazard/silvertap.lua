--! @todo this code is ugly!

local io = io or {open = function(a, b) end, popen = function (a) end}
local javascript_path = jsRequire and jsRequire('path')
local javascript_fs = jsRequire and jsRequire('fs')
local javascript_ps = jsRequire and jsRequire('child_process')
local real_io_open = io and io.open

local function bootstrap_has_file(filename, mode)
    if not BOOTSTRAP then return false end
    if BOOTSTRAP_DISABLE then return false end
    if not BOOTSTRAP[filename] then return false end
    if mode and not mode:find('r') then return false end
    return true
end

local function bootstrap_io_open(filename, mode)
    return {
        pointer = 1,
        lines = common_io_lines,
        read = function(self, size)
            return file_reader(self, mode, size, function()
                return BOOTSTRAP[filename]
            end)
        end,
        write = function() end,
        close = function() end
    }
end

--! wasmoon cannot pass binary strings, they cross as hex
local function to_hex(content)
    return (content:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end

local function from_hex(content)
    return (content:gsub('%x%x', function(x) return string.char(tonumber(x, 16)) end))
end

local function javascript_io_open(filename, mode)
    if (not mode or mode:find('r')) and not javascript_fs.existsSync(filename) then
        return nil
    end

    return {
        pointer = 1,
        content = '',
        lines = common_io_lines,
        read = function(self, size)
            return file_reader(self, mode, size, function()
                local binary = (mode or ''):find('b')
                if binary and javascript_fs.readFileHex then
                    return from_hex(javascript_fs.readFileHex(filename))
                end
                return javascript_fs.readFileSync(filename, not binary and 'utf8' or nil)
            end)
        end,
        write = function(self, content)
            self.content = self.content..content
        end,
        close = function(self)
            if not (mode or ''):find('w') then return end
            javascript_fs.mkdirSync(javascript_path.dirname(filename), {recursive = true, mode = 0})
            if (mode or ''):find('b') and javascript_fs.writeFileHex then
                javascript_fs.writeFileHex(filename, to_hex(self.content))
            elseif (mode or ''):find('b') then
                local blob, index = {}, 1
                while index <= #self.content do
                    blob[index] = string.byte(self.content, index)
                    index = index + 1
                end
                javascript_fs.writeFileSync(filename, Buffer.from(blob))
            else
                javascript_fs.writeFileSync(filename, self.content)
            end
        end
    }
end

io.open = function(filename, mode)
    local file = real_io_open and real_io_open(filename, mode)
    
    filename = filename or ''
    if javascript_fs then
        file = javascript_io_open(filename, mode)
    end

    filename = filename:gsub('\\', '/'):gsub('^./', '')
    if not file and bootstrap_has_file(filename, mode) then
        file = bootstrap_io_open(filename, mode)
    end

    return file
end

--! wasmoon os library works in emscripten virtual filesystem and environment
if javascript_fs and javascript_fs.unlinkSync then
    local javascript_env = jsRequire('process').env
    os.remove = function(filename)
        local ok, err = pcall(javascript_fs.unlinkSync, filename)
        if not ok then
            ok, err = pcall(javascript_fs.rmdirSync, filename)
        end
        if ok then return true end
        return nil, tostring(err)
    end
    os.getenv = function(name)
        return javascript_env[name]
    end
end

if jsRequire then
    os.execute = function(cmd)
        return pcall(javascript_ps.execSync, cmd)
    end
    io.popen = function(cmd)
        local ok, stdout = pcall(javascript_ps.execSync, cmd, {encoding='utf8'})
        return {
            pointer = 1,
            lines = common_io_lines,
            read = function(self, size)
                return file_reader(self, 'r', size, function()
                    return stdout
                end)
            end,
            write = function() end,
            close = function() return ok, '' end
        }
    end
end
