--! @brief ipk packer, the same layout as `opkg-build`
--! @details
--! an ar with `debian-binary`, `control.tar.gz` (only the control file) and
--! `data.tar.gz`, whose entries are `./<path>` from the filesystem root.
local ar = require('source/shared/string/encode/ar')
local tar = require('source/shared/string/encode/tar')
local gzip = require('source/shared/archive/gzip/encode')

local DEBIAN_BINARY = string.format('%d.%d\n', 2, 0)

local function fail(message)
    error(message, 0)
end

local function trim(text)
    return (text:gsub('^%s+', ''):gsub('%s+$', ''))
end

--! @short field value of a control, continuation lines included
local function get(control, key)
    local value = nil
    for line in (control..'\n'):gmatch('([^\n]*)\n') do
        line = line:gsub('\r$', '')
        if value and line:find('^[ \t]') then
            value = value..'\n'..trim(line)
        elseif value then
            return value
        else
            local name, rest = line:match('^([^:%s]+):(.*)$')
            if name == key then
                value = trim(rest)
            end
        end
    end
    return value
end

--! @short drop a field, continuation lines included
local function without(control, key)
    local out = {}
    local skip = false
    for line in (control..'\n'):gmatch('([^\n]*)\n') do
        if not (skip and line:find('^[ \t]')) then
            skip = line:match('^([^:%s]+):') == key
            if not skip and trim(line) ~= '' then
                out[#out + 1] = line..'\n'
            end
        end
    end
    return table.concat(out)
end

local function safe_name(name)
    return name:sub(1, 1) ~= '/'
        and not name:find('\\', 1, true)
        and not ('/'..name..'/'):find('/%.%./')
end

local function data_members(files)
    local members = {{name = './'}}
    local seen = {}
    local installed_size = 0
    local sorted = {}

    for index = 1, #files do
        sorted[index] = files[index]
    end
    table.sort(sorted, function(a, b) return a.name < b.name end)

    for _, file in ipairs(sorted) do
        if not safe_name(file.name) then
            fail('data: unsafe path "'..file.name..'"')
        end
        local dir = ''
        for part in file.name:gmatch('([^/]+)/') do
            dir = dir..part..'/'
            if not seen[dir] then
                seen[dir] = true
                members[#members + 1] = {name = './'..dir}
            end
        end
        installed_size = installed_size + #file.body
        members[#members + 1] = {name = './'..file.name, mode = file.mode, body = file.body}
    end

    return members, installed_size
end

local function build(control, files, options)
    local id, version = get(control, 'Package'), get(control, 'Version')
    local arch = get(control, 'Architecture') or 'all'

    if not id or #id == 0 then
        fail('control: missing the "Package:" field')
    end
    if not version or #version == 0 then
        fail('control: missing the "Version:" field')
    end
    if (id..version..arch):find('[%s/_]') then
        fail('control: "Package:", "Version:" and "Architecture:" cannot have spaces, "/" or "_"')
    end

    local members, installed_size = data_members(files)
    control = without(without(control, 'Architecture'), 'Installed-Size')
        ..'Architecture: '..arch..'\n'
        ..'Installed-Size: '..installed_size..'\n'

    local ipk = ar.encode({
        {name = 'debian-binary', body = DEBIAN_BINARY},
        {name = 'control.tar.gz', body = gzip.encode(tar.encode({{name = './control', body = control}}), options)},
        {name = 'data.tar.gz', body = gzip.encode(tar.encode(members), options)}
    })

    return id..'_'..version..'_'..arch..'.ipk', ipk
end

--! @short make an .ipk
--! @param control content of the control file, needs `Package` and `Version`
--! @param files list of `{name, body, mode}`, name relative to the install root
--! @param options `{level}` of the gzip compression
--! @return file name and content, or nil and the error message
local function encode(control, files, options)
    local ok, name, ipk = pcall(build, control, files, options)
    if not ok then
        return nil, name
    end
    return name, ipk
end

return {
    encode = encode
}
