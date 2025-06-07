local function build(src_in, bin_out)
    local src_file = io.open(src_in, 'r')

    if not src_file then
        return false, 'file not found: '..src_in
    end

    local content = src_file:read('*a')
    local bytecode1 = loadstring and loadstring(content) or load(content)
    local bytecode2 = string.dump(bytecode1, true)
    src_file:close()

    local bin_file = io.open(bin_out, 'wb')
    bin_file:write(bytecode2)
    bin_file:close()
    return true
end

local P = {
    build = build
}

return P
