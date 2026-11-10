var input = require('./input')
var runtime = require('./runtime')

/** drivers available in every bundle, lua virtual machines are added by the entry. */
module.exports = {
    runtime: runtime.runtime,
    resize: runtime.resize,
    keyboard: input.keyboard,
    gamepad: input.gamepad,
    'player-fake': require('./players/fake'),
    'player-html5': require('./players/html5'),
    'player-videojs': require('./players/videojs'),
    'player-youtube': require('./players/youtube')
}
