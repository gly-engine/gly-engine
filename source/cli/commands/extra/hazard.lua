local str_fs = require('source/shared/string/schema/fs')
local zeebo_package = require('source/cli/hazard/package')
local zeebo_filler = require('source/cli/hazard/filler')

local function package_mock(args)
    return zeebo_package.mock(args.file, args.mock, args.module)
end

local function template_fill(args)
    return zeebo_filler.put(args.file, tonumber(args.size))
end

local function template_replace(args)
    local src = str_fs.file(args.src).get_fullfilepath()
    local game = str_fs.file(args.game).get_fullfilepath()
    local output = str_fs.file(args.output).get_fullfilepath()
    return zeebo_filler.replace(src, game, output, args.size)
end

local P = {
    ['hazard-package-mock'] = package_mock,
    ['hazard-template-fill'] = template_fill,
    ['hazard-template-replace'] = template_replace
}

return P
