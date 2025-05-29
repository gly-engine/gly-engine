local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')

local function build(assets, dist)
    local index = 1
    while index <= #assets do
        local asset = assets[index]
        local separator = asset:find(':')
        local from = str_fs.file(separator and asset:sub(1, separator -1) or asset).get_fullfilepath()
        local to = str_fs.file(separator and asset:sub(separator + 1) or asset)
        cli_fs.mkdir(dist..to.get_sys_path())
        cli_fs.move(from, dist..to.get_fullfilepath())
        index = index + 1
    end
    return true
end

local P = {
    build = build
}

return P
