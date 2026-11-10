var util = require('../util')

/**
 * every `native_*` function and constant exposed to the engine.
 * @param {import('../types').Hypervisor} hv
 */
module.exports = function (hv) {
    var render = {canvas: hv.canvas, ctx: hv.ctx}
    return util.merge([
        require('./draw')(render),
        require('./text')(render),
        require('./image')(render),
        require('./media')(hv.players),
        require('./system')(hv)
    ])
}
