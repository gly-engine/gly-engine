var util = require('./util')

/** bundle entry with only wasmoon */
module.exports = require('./core')(util.merge([require('./driver'), {wasmoon: require('./driver/lua/wasmoon')}]))
