local os = require('os')

local cli_fs = require('source/cli/tools/fs')
local zeebo_bundler = require('source/cli/build/bundler')
local zeebo_bootstrap = require('source/cli/hazard/bootstrap')

local function cli_build(args)
    local dist = args.dist
    cli_fs.clear(dist)
    zeebo_bundler.build('source/cli/main.lua', dist..'main.lua')
    local deps = { './source', './assets', './samples', './tests/mock', './ee'}
    local ok, message = zeebo_bootstrap.build(dist..'main.lua', dist..'cli.lua', deps)
    os.remove(dist..'main.lua')
    return ok, message
end

local function cli_dump()
    return zeebo_bootstrap.dump()
end

local P = {
    ['cli-build'] = cli_build,
    ['cli-dump'] = cli_dump
}

return P
