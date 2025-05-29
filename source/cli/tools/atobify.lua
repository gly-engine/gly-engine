local base64 = require('src/lib/common/base64')
local util_fs = require('src/lib/util/fs')
local util_cmd = require('src/lib/util/cmd')

local function build(name, infile, outfile, delete_original)
    local infile_p, outfile_p = util_fs.file(infile), util_fs.file(outfile) 
    local infile_f, infile_err = io.open(infile_p.get_fullfilepath(), 'rb')

    if not infile_f then
        return false, infile_err or 'atobify opening infile: '..tostring(infile)
    end

    local content = infile_f:read('*a')
    content = 'window.'..name..'=atob(\''..base64.encode(content)..'\')\n'

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

    if delete_original then
        os.execute(util_cmd.del()..infile_p.get_fullfilepath())
    end

    return true
end

local P = {
    builder = function(a, b, c, d) return function() return build(a, b, c, d) end end,
    build = build
}

return P
