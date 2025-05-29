
--! @defgroup std
--! @{
--! @defgroup hash
--! @pre require @c hash
--! @{

--! @short std.hash.djb2
--! @param [in] digest string to hashing
--!
--! @li https://softwareengineering.stackexchange.com/questions/49550/which-hashing-algorithm-is-best-for-uniqueness-and-speed
--!
--! @return integer 32bit
local function djb2(digest)
    local index = 1
    local hash = 5381
    while index <= #digest do
        local char = string.byte(digest, index)
        hash = (hash * 33) + char
        index = index + 1
    end

    hash = string.format('%08x', hash)
    hash = tonumber(hash:sub(#hash - 7), 16)

    return hash
end

--! @}
--! @}

local function install(std, engine, cfg_system)
    local id = djb2(cfg_system.get_secret())
    std = std or {}
    std.hash = std.hash or {}
    std.hash.djb2 = djb2
    std.hash.fingerprint = function() return id end
end

local P = {
    install = install
}

return P
