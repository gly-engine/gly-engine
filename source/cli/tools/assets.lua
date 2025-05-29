local zeebo_fs = require('src/lib/cli/fs')
local util_fs = require('src/lib/util/fs')

local function build(assets, dist)
    local index = 1
    while index <= #assets do
        local asset = assets[index]
        local separator = asset:find(':')
        local from = util_fs.file(separator and asset:sub(1, separator -1) or asset).get_fullfilepath()
        local to = util_fs.file(separator and asset:sub(separator + 1) or asset)
        zeebo_fs.mkdir(dist..to.get_sys_path())
        zeebo_fs.move(from, dist..to.get_fullfilepath())
        index = index + 1
    end
    return true
end

local P = {
    build = build
}

return P
