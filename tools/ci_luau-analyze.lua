local cmd = function(c) assert(require('os').execute(c), c) end
local core = arg[1] or 'native'

local replace = './cli.sh fs-replace dist/main.lua dist/main.lua'

if core == 'cli' then
    cmd('./cli.sh bundler source/cli/main.lua')
    cmd(replace..' --format "BOOTSTRAP_DISABLE = true" --replace ""')
    cmd(replace..' --format "string.dump" --replace "string.format"')
    cmd(replace..' --format "arg = {args.game}" --replace ""')    
    cmd(replace..' --format "arg = nil" --replace ""')    
    cmd('./cli.sh hazard-package-mock tests/mock/json.lua dist/main.lua source_third_party_rxi_json')
    cmd('./cli.sh hazard-package-mock tests/mock/lustache.lua dist/main.lua source_third_party_olivinelabs_lustache')
    return
end

if ('asteroids pong'):find(core) then
    cmd('./cli.sh bundler samples/'..core..'/game.lua')
    cmd('mv dist/game.lua dist/main.lua')
    return
end

cmd('./cli.sh build --bundler --enterprise --core '..core)
cmd(replace..' --format "function native_callback" --replace "local function _native_callback"')
cmd('./cli.sh hazard-package-mock tests/mock/json.lua dist/main.lua source_third_party_rxi_json')
