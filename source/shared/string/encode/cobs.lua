
local function encode(data)
    local out, block = {}, {}

    local function close()
        out[#out + 1] = string.char(#block + 1)..table.concat(block)
        block = {}
    end

    for index = 1, #data do
        if #block == 254 then
            close()
        end
        local byte = data:sub(index, index)
        if byte == '\0' then
            close()
        else
            block[#block + 1] = byte
        end
    end
    close()

    return table.concat(out)
end

local function push(self, chunk)
    local parts, index, size = {}, 1, #chunk

    while index <= size do
        if self.left > 0 then
            local stop = math.min(size, index + self.left - 1)
            parts[#parts + 1] = chunk:sub(index, stop)
            self.left = self.left - (stop - index + 1)
            index = stop + 1
        else
            if self.zero then
                parts[#parts + 1] = '\0'
            end
            local code = chunk:byte(index)
            if code == 0 then
                error('invalid cobs: zero byte')
            end
            self.left = code - 1
            self.zero = code ~= 255
            index = index + 1
        end
    end

    return table.concat(parts)
end

local function decoder()
    return {left = 0, zero = false, push = push}
end

local function decode(data)
    return decoder():push(data)
end

local P = {
    encode = encode,
    decode = decode,
    decoder = decoder
}

return P
