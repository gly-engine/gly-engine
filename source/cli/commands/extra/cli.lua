local os = require('os')

local zeebo_fs = require('src/lib/cli/fs')
local zeebo_bundler = require('src/lib/cli/bundler')
local zeebo_bootstrap = require('src/lib/cli/bootstrap')

local function cli_test(args)
    local coverage = args.coverage and '-lluacov' or ''
    local files = zeebo_fs.ls('./tests/unit')
    local index = 1
    local ok = true
    while index <= #files do
        ok = ok and os.execute('lua '..coverage..' ./tests/unit/'..files[index])
        index = index + 1
    end
    if #coverage > 0 then
        os.execute('luacov src')
        os.execute('tail -n '..tostring(#files + 5)..' luacov.report.out')
    end
    return ok
end

local function cli_build(args)
    local dist = args.dist
    zeebo_fs.clear(dist)
    zeebo_bundler.build('src/cli/main.lua', dist..'main.lua')
    local deps = { './src', './assets', './samples', './mock', './ee', './third_party'}
    local ok, message = zeebo_bootstrap.build(dist..'main.lua', dist..'cli.lua', deps)
    os.remove(dist..'main.lua')
    return ok, message
end

local function cli_dump()
    return zeebo_bootstrap.dump()
end

local P = {
    ['cli-build'] = cli_build,
    ['cli-test'] = cli_test,
    ['cli-dump'] = cli_dump
}

return P
