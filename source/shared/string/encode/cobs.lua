--! @short Consistent Overhead Byte Stuffing
--! @brief body without zero bytes, as haio writes with @c ?encoding=cobs
--! @details
--! some ginga televisions hand a tcp read to lua as a c string, so everything after
--! a zero byte in each read is lost. cobs removes every zero at the cost of at most
--! one byte in 254.
--!
--! every block starts with a code: the code minus one bytes follow it, and a zero
--! comes after them unless the code is 255 or the block is the last one.
--! @note no frame delimiter is written or expected.

--! @cond
local function encode(data)
    local out, block = {}, {}

    local function close()
        out[#out + 1] = string.char(#block + 1)..table.concat(block)
        block = {}
    end

    for index = 1, #data do
        -- a full block is only closed when something follows it
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

--! decodes a chunk and keeps where it stopped, so a block may span any number of chunks
local function push(self, chunk)
    local parts, index, size = {}, 1, #chunk

    while index <= size do
        if self.left > 0 then
            local stop = math.min(size, index + self.left - 1)
            parts[#parts + 1] = chunk:sub(index, stop)
            self.left = self.left - (stop - index + 1)
            index = stop + 1
        else
            -- the zero of the block before is only written once another block exists
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
--! @endcond

--! @short streaming decoder
--! @return object with @c push(self, chunk) that returns the decoded bytes of that chunk
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
