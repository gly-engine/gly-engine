-- bytesex
local function to_uint32_be(s)
    local b1,b2,b3,b4 = s:byte(1,4)
    return ((b1*256+b2)*256+b3)*256+b4
end

local function check_error(path)
    local f = io.open(path,"rb")
    if not f then return false, "file not found" end

    local header = f:read(8)
    if header ~= "\137PNG\r\n\26\n" then
        f:close()
        return false, "missing or invalid PNG header"
    end

    while true do
        local len_bytes = f:read(4)
        if not len_bytes or #len_bytes < 4 then break end

        local length = to_uint32_be(len_bytes)
        local ctype = f:read(4)
        if not ctype or #ctype < 4 then f:close(); return false, "invalid chunk type" end

        local data = f:read(length)
        if not data or #data < length then f:close(); return false, "incomplete chunk data" end

        if not f:read(4) then f:close(); return false, "missing chunk CRC" end

        if ctype == "IEND" then
            if not f:read(1) then
                f:close()
                return true, nil
            else
                f:close()
                return false, "extra data after IEND"
            end
        end
    end

    f:close()
    return false, "missing IEND chunk"
end


return {
    check_error = check_error
}
