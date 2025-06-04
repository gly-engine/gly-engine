local build = require('source/cli/commands/build/main')
local build_html = require('source/cli/commands/build/html')
local zeebo_compiler = require('source/cli/build/compiler')
local zeebo_bundler = require('source/cli/build/bundler')
local cli_fs = require('source/cli/tools/fs')
local str_fs = require('source/shared/string/schema/fs')

local function bundler(args)
    local from = str_fs.file(args.src)
    local to = str_fs.file(args.outfile)
    cli_fs.clear(to.get_sys_path())
    return zeebo_bundler.build(from.get_fullfilepath(), to.get_fullfilepath())
end

local function compile(args)
    local from = str_fs.file(args.src)
    local to = str_fs.file(args.outfile)
    return zeebo_compiler.build(from.get_fullfilepath(), to.get_fullfilepath())
end

local P = {
    bundler = bundler,
    compile = compile,
    build = build.build,
    ['build-html'] = build_html.build
}

return P
