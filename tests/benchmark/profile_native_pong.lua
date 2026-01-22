local profile = require('source/third_party/2dengine_profile')
local pong = require('samples/pong/game')
require('tests/mock/core_native')
require('source/engine/core/vacuum/native/main')

native_callback_init(1280, 720, pong)
profile.start()
for _ = 1, 1000 do
    native_callback_loop(16)
    native_callback_draw()
end
profile.stop()
print(profile.report(20))
