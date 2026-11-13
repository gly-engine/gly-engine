--! @brief sign and encrypt of `opkg build --protect`, with the nodejs crypto of gly-cli
--! @details
--! the data.tar.gz is sealed with AES-256-GCM (`nonce || ciphertext || tag`),
--! keyed by `sha256("opkg data.tar.gz v1\0" || public key)`; the control gets
--! `Key:` (sha1 of the ed25519 public key) and `Signature:` (ed25519, base64)
--! over `sha256(control without Signature) || sha256(sealed data)`.
local AES_LABEL = 'opkg data.tar.gz v1\0'
local NONCE_SIZE = 12

local byte_hex, hex_byte = {}, {}
for index = 0, 255 do
    local hex = string.format('%02x', index)
    byte_hex[string.char(index)] = hex
    hex_byte[hex] = string.char(index)
end

local function to_hex(bytes)
    return (bytes:gsub('.', byte_hex))
end

local function from_hex(hex)
    return (hex:lower():gsub('%x%x', hex_byte))
end

--! @short protector for ipk encode, from the content of an ed25519 private key (PEM)
--! @param pem key content, nil when the file was not found
--! @param name key file, for the error message
--! @return table `{key, seal, sign}` or nil and the error message
local function new(pem, name)
    local crypto = jsRequire and jsRequire('crypto')
    if not crypto or not crypto.publicKey then
        return nil, '--protect is only available in the nodejs gly-cli (npx gly-cli)'
    end
    if not pem then
        return nil, 'private key not found: '..(name or '')
    end

    local ok, public = pcall(crypto.publicKey, pem)
    if not ok then
        return nil, (name or 'key')..': not an ed25519 private key (PEM)'
    end
    public = from_hex(public)

    local aes_key = crypto.hash('sha256', to_hex(AES_LABEL..public))
    local function sha256(data)
        return from_hex(crypto.hash('sha256', to_hex(data)))
    end

    return {
        key = crypto.hash('sha1', to_hex(public)),
        seal = function(data)
            local nonce = crypto.randomBytes(NONCE_SIZE)
            return from_hex(nonce..crypto.aes256gcm(aes_key, nonce, to_hex(data)))
        end,
        sign = function(control, sealed)
            return crypto.sign(pem, to_hex(sha256(control)..sha256(sealed)))
        end
    }
end

return {
    new = new
}
