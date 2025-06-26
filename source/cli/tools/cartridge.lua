-- Creates a .tic cartridge manually with CODE and DEFAULT chunks
local function tic80(metadata, workdir)
    local function writeChunk(file, bank, chunkType, data)
        local size = #data
        local header = string.char(
            (bank << 5) | chunkType,  -- Byte 0: Bank + Type
            size % 256,               -- Byte 1: Size LSB
            math.floor(size / 256),   -- Byte 2: Size MSB
            0x00                      -- Byte 3: Reserved
        )
        file:write(header)
        file:write(data)
    end

    -- Open input and output files
    local engineFile = io.open(workdir..'engine.lua', 'r')
    local gameFile = io.open(workdir..'game.lua', 'r')
    local outputFile = io.open(workdir..'game.tic', 'wb')
    local backendFile = io.open(workdir..'main.lua', 'r')

    -- Read Lua code from files
    local var = metadata()
    local metaCode = var.dump.meta.tic80()
    local gameCode = gameFile:read('*a')
    local engineCode = engineFile:read('*a')
    local backendCode = backendFile:read('*a')
    
    metaCode = metaCode..'\n'
    gameCode = 'local tic80game = function()\n' .. gameCode .. '\nend\n'
    engineCode = 'local tic80engine = function()\n' .. engineCode .. '\nend\n'

    if #engineCode >= 65536 then
        return false, 'engine is too large! (prefer --engine @nano)'
    end

    if (#metaCode + #gameCode + #engineCode + #backendCode) > (65536 - 32) then
        return false, 'not enough space on cartridge! (65KB)'
    end
    
    -- Default chunk data (default configuration)
    local defaultChunk = string.char(0x00)

    -- Write chunks to the .tic file
    writeChunk(outputFile, 3, 5, metaCode)
    writeChunk(outputFile, 2, 5, gameCode)
    writeChunk(outputFile, 1, 5, engineCode)
    writeChunk(outputFile, 0, 5, backendCode)
    writeChunk(outputFile, 0, 17, defaultChunk)

    outputFile:close()

    return true
end

local P = {
    tic80 = tic80,
    builder_tic80 = function(a, b, c, d) return function() return tic80(a, b, c, d) end end
}

return P
