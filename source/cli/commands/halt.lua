local build = require('source/cli/commands/build/main')
local build_html = require('source/cli/commands/build/html')
local zeebo_compiler = require('source/cli/build/compiler')
local zeebo_bundler = require('source/cli/build/bundler')
local str_fs = require('source/shared/string/schema/fs')
local cli_fs = require('source/cli/tools/fs')
local cli_meta = require('source/cli/tools/meta')
local cli_initialize = require('source/cli/tools/initialize')

local function init(args)
    return cli_initialize.init(args)
end

local function run(args)
    if BOOTSTRAP then
        return false, 'core love2d is not avaliable in bootstraped CLI.'
    end
    local love = 'love'
    local screen = args['screen'] and ('-'..'-screen '..args.screen) or ''
    local command = love..' source/engine/core/love '..screen..' '..args.game
    if not os or not os.execute then
        return false, 'cannot can execute'
    end
    return os.execute(command)
end

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

local function test(args)
    local coverage = args.coverage and '-lluacov' or ''
    local files = cli_fs.ls('./tests/unit')
    local ok, index = true, 1
    while index <= #files do
        ok = ok and os.execute(args.luabin..' '..coverage..' ./tests/unit/'..files[index])
        index = index + 1
    end
    if #coverage > 0 then
        os.execute('luacov src')
        os.execute('tail -n '..tostring(#files + 5)..' luacov.report.out')
    end
    return ok
end

local function meta(args)
    arg = nil -- prevent infinite loop
    local format = args.format

    if args.infile and #args.infile > 0 then
        local infile_f, infile_err = io.open(str_fs.file(args.infile).get_fullfilepath(), 'r')
        if not infile_f then
            return false, infile_err or args.infile
        end
        format = infile_f:read('*a')
    end

    local content = cli_meta.render(args.src, format)
    if not content then
        return false, 'cannot parse: '..args.src
    end

    if args.outfile and #args.outfile > 0 then
        local outfile_f, outfile_err = io.open(str_fs.file(args.outfile).get_fullfilepath(), 'w')
        if not outfile_f then
            return false, outfile_err or args.outfile
        end
        outfile_f:write(content)
        outfile_f:close()
        content = nil
    end

    return true, content
end

local P = {
    run = run,
    init = init,
    test = test,
    meta = meta,
    bundler = bundler,
    compile = compile,
    build = build.build,
    ['build-html'] = build_html.build
}

return P
