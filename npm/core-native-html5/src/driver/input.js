var presets = require('./presets.json')

var DEAD_ZONE = 0.2

/**
 * @template T
 * @param {Record<string, T>} map
 * @param {T | string | undefined} value custom map or preset name
 * @returns {T}
 */
function preset(map, value) {
    return value && typeof value == 'object' ? value : map[String(value)] || map['default']
}

/** @type {import('../types').Driver} */
var keyboard = {
    /** @param {Array<[string | number, string]> | string} [keys] pairs of `[code or keyCode, key]` */
    startup: function (hv, keys) {
        var keymap = preset(/** @type {any} */ (presets.keymap), keys)
        /** @param {KeyboardEvent} ev */
        function handler(ev) {
            for (var i = 0; i < keymap.length; i++) {
                if (keymap[i][0] === ev.code || keymap[i][0] === ev.keyCode) {
                    ev.preventDefault()
                    return hv.frontend.native_callback_keyboard(keymap[i][1], ev.type === 'keydown' ? 1 : 0)
                }
            }
        }
        hv.listen(document, 'keydown', /** @type {EventListener} */ (handler))
        hv.listen(document, 'keyup', /** @type {EventListener} */ (handler))
    }
}

/** @type {import('../types').Driver} */
var gamepad = {
    /** @param {{pads: string[], axis: string[]} | string} [keys] */
    startup: function (hv, keys) {
        var map = preset(/** @type {any} */ (presets.padmap), keys)
        /** @type {number[]} */
        var buttons = []
        /** @type {number[]} */
        var axis = []

        /**
         * @param {number[]} state
         * @param {number} index
         * @param {string} key
         * @param {number} value
         */
        function trigger(state, index, key, value) {
            if ((state[index] || 0) !== value) {
                state[index] = value
                hv.frontend.native_callback_keyboard(key, value)
            }
        }

        hv.bus.on('pad', function () {
            var pads = navigator.getGamepads ? navigator.getGamepads() : []
            for (var p = 0; p < pads.length; p++) {
                var pad = pads[p]
                if (!pad) {
                    continue
                }
                for (var b = 0; b < map.pads.length; b++) {
                    trigger(buttons, b, map.pads[b], pad.buttons[b] && pad.buttons[b].pressed ? 1 : 0)
                }
                for (var a = 0; a < map.axis.length; a++) {
                    var value = pad.axes[Math.floor(a / 2)]
                    trigger(axis, a, map.axis[a], (a & 1 ? value > DEAD_ZONE : value < -DEAD_ZONE) ? 1 : 0)
                }
            }
        })
    }
}

module.exports = {
    keyboard: keyboard,
    gamepad: gamepad
}
