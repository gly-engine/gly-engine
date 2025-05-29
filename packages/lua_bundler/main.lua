local zeebo_bundler = require('source/cli/build/bundler')
local str_fs = require('source/shared/string/schema/fs')
local os = require('os')

local f = str_fs.file(arg[1] or './src/main.lua')
local d = (arg[2] and str_fs.file(arg[2])) or str_fs.path('./dist', f.get_file())
local ok, msg = zeebo_bundler.build(f.get_fullfilepath(), d.get_fullfilepath())

if not ok then
    print(msg)
    if os then os.exit(1) end
end
