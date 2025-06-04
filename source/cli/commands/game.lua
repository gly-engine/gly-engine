local os = require('os')
local str_fs = require('source/shared/string/schema/fs')
local cli_meta = require('source/cli/tools/meta')

local function init(args)
    return false, 'not implemented!'
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
    meta = meta,
    init = init
}

return P
