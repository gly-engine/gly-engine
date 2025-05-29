local zeebo_compiler = require('src/lib/cli/compiler')
local zeebo_bundler = require('source/cli/build/bundler')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')

local function bundler(args)
    local d = str_fs.path(args.dist)
    local f = str_fs.file(args.file)
    cli_fs.clear(d.get_fullfilepath())
    return zeebo_bundler.build(f.get_fullfilepath(), d.get_sys_path()..f.get_file())
end

local function compiler(args)
    local file = str_fs.file(args.file).get_fullfilepath()
    local dist = str_fs.file(args.dist).get_fullfilepath()
    return zeebo_compiler.build(file, dist)
end

local P = {
    bundler = bundler,
    compiler = compiler
}

return P
