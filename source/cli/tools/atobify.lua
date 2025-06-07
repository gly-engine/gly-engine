local str_base64 = require('source/shared/string/encode/base64')
local str_fs = require('source/shared/string/schema/fs')

local function build(name, infile, outfile)
    local infile_p, outfile_p = str_fs.file(infile), str_fs.file(outfile) 
    local infile_f, infile_err = io.open(infile_p.get_fullfilepath(), 'rb')

    if not infile_f then
        return false, infile_err or 'atobify opening infile: '..tostring(infile)
    end

    local content = infile_f:read('*a')
    content = 'window.'..name..'=atob(\''..str_base64.encode(content)..'\')\n'

    local outfile_f, outfile_err = io.open(outfile_p.get_fullfilepath(), 'r')
    if outfile_f then
        content = outfile_f:read('*a')..content
        outfile_f:close()
    end

    outfile_f, outfile_err = io.open(outfile_p.get_fullfilepath(), 'w')
    if not outfile_f then
        return false, outfile_err or 'atobify opening outfile: '..tostring(infile)
    end

    outfile_f:write(content)
    outfile_f:close()

    return true
end

local P = {
    builder = function(a, b, c) return function() return build(a, b, c) end end,
    build = build
}

return P
