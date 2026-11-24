--! @brief ipk packer, the same layout as `opkg-build`
--! @details
--! an ar with `debian-binary`, `control.tar.gz` (only the control file) and
--! `data.tar.gz`, whose entries are `./<path>` from the filesystem root.
--! the control is re-written one `Field: value` per line, as signed by `protect`.
local ar = require('source/shared/string/encode/ar')
local tar = require('source/shared/string/encode/tar')
local gzip = require('source/shared/archive/gzip/encode')
local stanza = require('source/shared/archive/ipk/stanza')

local fail = stanza.fail

local DEBIAN_BINARY = string.format('%d.%d\n', 2, 0)

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
    local fields = stanza.parse(control)
    local id, version = stanza.get(fields, 'Package'), stanza.get(fields, 'Version')
    local arch = stanza.get(fields, 'Architecture') or 'all'
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
    fields = stanza.without(fields, {Architecture = true, ['Installed-Size'] = true, Key = true, Signature = true})
    fields[#fields + 1] = {key = 'Architecture', value = arch}
    fields[#fields + 1] = {key = 'Installed-Size', value = tostring(installed_size)}

    local data = gzip.encode(tar.encode(members), options)
    if protect then
        fields[#fields + 1] = {key = 'Key', value = protect.key}
        data = protect.seal(data)
        fields[#fields + 1] = {key = 'Signature', value = protect.sign(stanza.write(fields), data)}
    end

    local ipk = ar.encode({
        {name = 'debian-binary', body = DEBIAN_BINARY},
        {name = 'control.tar.gz', body = gzip.encode(tar.encode({{name = './control', body = stanza.write(fields)}}), options)},
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
