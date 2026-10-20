local zeebo_bundler_js = require('source/cli/build/bundler_js')

--! @short bundle of npm/core-native-html5 with only the lua vm selected by flag
local function builder(args)
    return function()
        local entry = 'npm/core-native-html5/src/'..(args.fengari and 'fengari' or 'wasmoon')..'.js'
        return zeebo_bundler_js.build(entry, args.outdir..'core-native.js', {global='CoreNativeHtml5'})
    end
end

local P = {
    builder = builder
}

return P
