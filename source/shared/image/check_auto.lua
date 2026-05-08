local function auto(buf)
    if type(buf) == "string" then
        local b1 = buf:byte(1)
        local b2 = buf:byte(2)
        local b3 = buf:byte(3)
        local b4 = buf:byte(4)

        if b1 == 0xFF and b2 == 0xD8 and b3 == 0xFF then
            return "jpeg"
        end

        if b1 == 0x89 and b2 == 0x50 and b3 == 0x4E and b4 == 0x47 then
            return "png"
        end

        if b1 == 0x50 and b2 == 0x36 then
            return "p6"
        end

        if buf:sub(1, 9) == "YUV4MPEG2" then
            return "y4m"
        end
    end

    return nil
end

return auto
