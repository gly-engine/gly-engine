--! @brief sign and encrypt of `opkg build --key`, with the nodejs crypto of gly-cli
--! @details
--! the data.tar.gz is sealed with AES-256-GCM (`nonce || ciphertext || tag`),
--! keyed by `sha256("opkg data.tar.gz v1\0" || public key)`; the control gets
--! `Key:` (sha1 of the ed25519 public key) and `Signature:` (ed25519, base64)
--! over `sha256(control without Signature) || sha256(sealed data)`.
--! because the cipher key comes from the public key, opening a package needs
--! only the public half, and signing one needs the private half.
local AES_LABEL = 'opkg data.tar.gz v1\0'
local NONCE_SIZE = 12

--! @short the fixed base64 head of an ed25519 key, the OID always lands here
local ED25519_HEAD = {
    private = 'MC4CAQAwBQYDK2Vw',
    public = 'MCowBQYDK2VwAyEA'
}

--! @short what each PEM banner means, before any crypto is asked for
local PEM_KINDS = {
    ['PRIVATE KEY'] = {private = true},
    ['PUBLIC KEY'] = {private = false},
    ['ENCRYPTED PRIVATE KEY'] = {error = 'is encrypted, a passphrase is not supported'},
    ['OPENSSH PRIVATE KEY'] = {error = 'is an openssh key, convert it with "openssl pkey"'},
    ['RSA PRIVATE KEY'] = {error = 'is an rsa key, it has to be ed25519'},
    ['EC PRIVATE KEY'] = {error = 'is an elliptic curve key, it has to be ed25519'},
    ['CERTIFICATE'] = {error = 'is a certificate, not a key'}
}

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

--! @short tell a private key from a public one by the PEM banner
--! @return true for private, false for public, or nil and the error message
local function inspect(pem, name)
    name = name or 'key'
    if not pem then
        return nil, 'key not found: '..name
    end

    local banner = pem:match('%-%-%-%-%-BEGIN ([A-Z0-9 ]+)%-%-%-%-%-')
    if not banner then
        if pem:find('^ssh%-ed25519%s') then
            return nil, name..' is an openssh public key, convert it with "openssl pkey"'
        end
        return nil, name..' is not a PEM key'
    end

    local kind = PEM_KINDS[banner]
    if not kind then
        return nil, name..': unsupported PEM "'..banner..'"'
    end
    if kind.error then
        return nil, name..' '..kind.error
    end

    local head = pem:match('%-%-%-%-%-\r?\n%s*([A-Za-z0-9+/]+)')
    local want = kind.private and ED25519_HEAD.private or ED25519_HEAD.public
    if head and head:sub(1, #want) ~= want then
        return nil, name..' is not an ed25519 key'
    end

    return kind.private
end

--! @short protector for the ipk encode and decode, from a PEM key
--! @param pem key content, nil when the file was not found
--! @param name key file, for the error message
--! @return table `{key, private, verify, unseal, seal, sign}` or nil and the error message
--! @details `seal` and `sign` only come with a private key
local function new(pem, name)
    local private, err = inspect(pem, name)
    if private == nil then
        return nil, err
    end

    local crypto = jsRequire and jsRequire('crypto')
    if not crypto or not crypto.publicKey then
        return nil, '--key is only available in the nodejs gly-cli (npx gly-cli)'
    end

    local ok, public = pcall(crypto.publicKey, pem)
    if not ok then
        return nil, (name or 'key')..': not an ed25519 key (PEM)'
    end
    public = from_hex(public)

    local aes_key = crypto.hash('sha256', to_hex(AES_LABEL..public))
    local function sha256(data)
        return from_hex(crypto.hash('sha256', to_hex(data)))
    end
    local function message(control, sealed)
        return to_hex(sha256(control)..sha256(sealed))
    end

    local protector = {
        key = crypto.hash('sha1', to_hex(public)),
        private = private,
        verify = function(control, sealed, signature)
            return crypto.verify(pem, message(control, sealed), signature) == '1'
        end,
        unseal = function(sealed)
            if #sealed <= NONCE_SIZE then
                return nil
            end
            local nonce = to_hex(sealed:sub(1, NONCE_SIZE))
            local body = to_hex(sealed:sub(NONCE_SIZE + 1))
            local opened = crypto.aes256gcmOpen(aes_key, nonce, body)
            return opened and from_hex(opened)
        end
    }

    if private then
        protector.seal = function(data)
            local nonce = crypto.randomBytes(NONCE_SIZE)
            return from_hex(nonce..crypto.aes256gcm(aes_key, nonce, to_hex(data)))
        end
        protector.sign = function(control, sealed)
            return crypto.sign(pem, message(control, sealed))
        end
    end

    return protector
end

return {
    new = new,
    inspect = inspect
}
