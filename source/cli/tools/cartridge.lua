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
        return false, 'engine is too large! (prefer -'..'-engine @nano)'
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

-- Cria um cartucho .p8 com seções básicas (__lua__ obrigatória)
local function pico8(metadata, workdir)
    -- Abertura dos arquivos
    local engineFile = io.open(workdir .. 'engine.lua', 'r')
    local gameFile = io.open(workdir .. 'game.lua', 'r')
    local backendFile = io.open(workdir .. 'main.lua', 'r')
    local outputFile = io.open(workdir .. 'game.p8', 'w')

    if not (engineFile and gameFile and backendFile and outputFile) then
        return false, 'missing input or output file'
    end

    -- Lê os códigos-fonte
    local var = ''--metadata()
    local metaCode = ''--var.dump.meta.pico8 and var.dump.meta.pico8() or ""
    local engineCode = engineFile:read('*a') or ""
    local gameCode = gameFile:read('*a') or ""
    local backendCode = backendFile:read('*a') or ""

    engineFile:close()
    gameFile:close()
    backendFile:close()

    -- Organiza o código Lua com wrappers como na versão do TIC-80
    metaCode = metaCode .. '\n'
    gameCode = 'local pico8game = function()\n' .. gameCode .. '\nend\n'
    engineCode = 'local pico8engine = function()\n' .. engineCode .. '\nend\n'
    backendCode = backendCode .. '\n'

    local luaCode = metaCode .. engineCode .. gameCode .. backendCode

    -- Cabeçalho PICO-8
    outputFile:write('pico-8 cartridge // http://www.pico-8.com\n')
    outputFile:write('version 8\n\n')

    -- Seção __lua__
    outputFile:write('__lua__\n')
    outputFile:write(luaCode)

    -- Outras seções vazias são opcionais, mas podem ser incluídas se necessário
    -- Aqui está um exemplo com __gfx__ e __map__ vazios:
    outputFile:write('\n__gfx__\n')
    for _ = 1, 64 do
        outputFile:write('0000000000000000000000000000000000000000000000000000000000000000\n')
    end

    outputFile:write('\n__map__\n')
    for _ = 1, 32 do
        outputFile:write('0000' .. string.rep('0', 255) .. '\n')
    end

    -- Outras seções (__gff__, __sfx__, __music__, etc.) poderiam ser adicionadas conforme necessário.

    outputFile:close()
    return true
end

local P = {
    pico8 = pico8,
    tic80 = tic80,
    builder_pico8 = function(a, b) return function() return pico8(a, b) end end,
    builder_tic80 = function(a, b) return function() return tic80(a, b) end end
}

return P
