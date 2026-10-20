var util = require('./util')

/** bundle entry with only fengari */
module.exports = require('./core')(util.merge([require('./driver'), {fengari: require('./driver/lua/fengari')}]))
