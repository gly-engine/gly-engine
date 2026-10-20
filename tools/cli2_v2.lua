local cli2 = require('source/shared/string/dsl/cli2')
local json = require('source/third_party/rxi_json')

local commands = json.decode_file('cmds.json')
local ok_dsl, msg_dsl, dsl = cli2.load_cmds(commands)

if not ok_dsl then print(msg_dsl) return end 

local ok, msg, state = cli2.parse(dsl, arg)
local result = json.encode(state)

if msg and #msg > 0 then print (msg) end

print(result)
print(ok)