--! @brief ipk packer, the same layout as `opkg-build`
--! @details
--! an ar with `debian-binary`, `control.tar.gz` (only the control file) and
--! `data.tar.gz`, whose entries are `./<path>` from the filesystem root.
--! the control is re-written one `Field: value` per line, as signed by `protect`.
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

--! @short parse the control into `{key, value}` fields, in file order
--! @details same rules of the verifier, that signs the control re-written by write_stanza
local function parse_stanza(control)
    local fields = {}
    local last = nil
    local ended = false

    for line in (control..'\n'):gmatch('([^\n]*)\n') do
        line = line:gsub('\r$', '')
        if trim(line) == '' then
            ended = #fields > 0
        elseif ended then
            fail('control: only one package per file, found a blank line between fields')
        elseif line:find('^[ \t]') then
            if not last then
                fail('control: line "'..line..'" continues no field')
            end
            local value = trim(line)
            if #value > 0 then
                last.value = #last.value > 0 and last.value..'\n'..value or value
            end
        else
            local key, value = line:match('^([^:]*):(.*)$')
            if not key or trim(key) == '' then
                fail('control: line "'..line..'" is not "Field: value"')
            end
            last = {key = trim(key), value = trim(value)}
            fields[#fields + 1] = last
        end
    end

    return fields
end

local function write_stanza(fields)
    local out = {}
    for _, field in ipairs(fields) do
        local first = true
        for line in (field.value..'\n'):gmatch('([^\n]*)\n') do
            out[#out + 1] = first and (field.key..': '..line..'\n') or (' '..line..'\n')
            first = false
        end
    end
    return table.concat(out)
end

local function get(fields, key)
    for _, field in ipairs(fields) do
        if field.key == key then
            return field.value
        end
    end
end

local function without(fields, keys)
    local out = {}
    for _, field in ipairs(fields) do
        if not keys[field.key] then
            out[#out + 1] = field
        end
    end
    return out
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
    local fields = parse_stanza(control)
    local id, version = get(fields, 'Package'), get(fields, 'Version')
    local arch = get(fields, 'Architecture') or 'all'
    local protect = options and options.protect

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
    fields = without(fields, {Architecture = true, ['Installed-Size'] = true, Key = true, Signature = true})
    fields[#fields + 1] = {key = 'Architecture', value = arch}
    fields[#fields + 1] = {key = 'Installed-Size', value = tostring(installed_size)}

    local data = gzip.encode(tar.encode(members), options)
    if protect then
        fields[#fields + 1] = {key = 'Key', value = protect.key}
        data = protect.seal(data)
        fields[#fields + 1] = {key = 'Signature', value = protect.sign(write_stanza(fields), data)}
    end

    local ipk = ar.encode({
        {name = 'debian-binary', body = DEBIAN_BINARY},
        {name = 'control.tar.gz', body = gzip.encode(tar.encode({{name = './control', body = write_stanza(fields)}}), options)},
        {name = 'data.tar.gz', body = data}
    })

    return id..'_'..version..'_'..arch..'.ipk', ipk
end

--! @short make an .ipk
--! @param control content of the control file, needs `Package` and `Version`
--! @param files list of `{name, body, mode}`, name relative to the install root
--! @param options `{level, protect}`: gzip level, and `{key, seal, sign}` to sign and encrypt
--! (`key` goes to `Key:`, `seal(data.tar.gz)` encrypts it, `sign(control, sealed)` gives `Signature:`)
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
