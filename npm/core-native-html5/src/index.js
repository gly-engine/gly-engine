var util = require('./util')

/** bundle entry with every driver */
module.exports = require('./core')(util.merge([require('./driver'), {
    fengari: require('./driver/lua/fengari'),
    wasmoon: require('./driver/lua/wasmoon')
}]))
