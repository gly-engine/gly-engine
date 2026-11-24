--! @brief ipk reader, the counterpart of the ipk encode
--! @details takes the ar apart, reads the control out of `control.tar.gz` and
--! the files out of `data.tar.gz`. a package with `Key:` and `Signature:` is
--! verified and decrypted by `protect` before a single file is handed back.
local ar = require('source/shared/string/decode/ar')
local tar = require('source/shared/string/decode/tar')
local gzip = require('source/shared/archive/gzip/decode')
local stanza = require('source/shared/archive/ipk/stanza')

local fail = stanza.fail

local DEBIAN_BINARY = '2.0'
local CONTROL_FILE = 'control'

--! @short the archive spelling of a path, `./usr/bin` and `usr/bin` are the same entry
local function clean(name)
    return (name:gsub('^%./', ''):gsub('/$', ''))
end

local function member(members, name)
    for _, entry in ipairs(members) do
        if entry.name == name then
            return entry.body
        end
    end
    fail('ipk: missing '..name)
end

local function read_control(body)
    local control = nil
    for _, entry in ipairs(tar.decode(gzip.decode(body))) do
        local name = clean(entry.name)
        if name == CONTROL_FILE then
            control = entry.body
        elseif #name > 0 and not entry.directory then
            fail('ipk: unexpected "'..entry.name..'" in control.tar.gz')
        end
    end
    if not control then
        fail('ipk: missing control in control.tar.gz')
    end
    return control
end

local function read_data(body)
    local files = {}
    for _, entry in ipairs(tar.decode(gzip.decode(body))) do
        local name = clean(entry.name)
        if #name > 0 and not entry.directory then
            if name == CONTROL_FILE then
                fail('ipk: control must be inside control.tar.gz')
            end
            files[#files + 1] = {name = name, body = entry.body, mode = entry.mode}
        end
    end
    return files
end

local function unseal(fields, data, protect)
    local key = stanza.get(fields, 'Key')
    local signature = stanza.get(fields, 'Signature')

    if not key and not signature then
        return data
    end
    if not key or not signature then
        fail('control: "Key:" and "Signature:" go together')
    end
    if not protect then
        fail('this package is protected, it needs the key that signed it')
    end
    if protect.key ~= key then
        fail('this package was signed by the key '..key..', not by '..protect.key)
    end
    local signed = stanza.write(stanza.without(fields, {Signature = true}))
    if not protect.verify(signed, data, signature) then
        fail('invalid signature for the key '..key)
    end

    return protect.unseal(data)
end

local function extract(content, options)
    local members = ar.decode(content)
    local protect = options and options.protect

    if (member(members, 'debian-binary'):gsub('%s+$', '')) ~= DEBIAN_BINARY then
        fail('ipk: unsupported debian-binary version')
    end

    local control = read_control(member(members, 'control.tar.gz'))
    local fields = stanza.parse(control)
    local data = unseal(fields, member(members, 'data.tar.gz'), protect)

    return stanza.write(fields), read_data(data)
end

--! @short open an .ipk
--! @param content the whole package
--! @param options `{protect}`, the `{key, verify, unseal}` that opens a protected one
--! @return control content and the list of `{name, body, mode}`, or nil and the error message
local function decode(content, options)
    local ok, control, files = pcall(extract, content, options)
    if not ok then
        return nil, control
    end
    return control, files
end

return {
    decode = decode
}
