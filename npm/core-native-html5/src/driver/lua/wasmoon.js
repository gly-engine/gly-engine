/**
 * lua 5.4 in webassembly, https://github.com/ceifa/wasmoon
 * @type {import('../../types').Driver}
 */
module.exports = {
    /**
     * @param {any} LuaFactory
     * @param {any} LuaMultiReturn
     */
    install: async function (hv, LuaFactory, LuaMultiReturn) {
        if (!LuaFactory || !LuaMultiReturn) {
            throw new Error('wasmoon is required!')
        }

        var lua = await new LuaFactory().createEngine()
        var global = lua.global

        /**
         * arrays are returned as multiple values
         * @param {Function} func
         */
        function multi(func) {
            return function () {
                var res = func.apply(null, arguments)
                return Array.isArray(res) ? LuaMultiReturn.from(res) : res
            }
        }

        for (var key in hv.backend) {
            var value = hv.backend[key]
            if (value !== undefined) {
                global.set(key, typeof value == 'function' ? multi(value) : value)
            }
        }

        global.set('native_json_encode', JSON.stringify)
        global.set('native_json_decode', JSON.parse)
        global.set('native_base64_encode', btoa)
        global.set('native_base64_decode', atob)

        await lua.doString(await hv.code.engine())

        hv.vm.close = function () {
            global.close()
        }
        hv.vm.call = function (/** @type {string} */ name, /** @type {any[]} */ args) {
            return global.get(name).apply(null, args)
        }
    },
    destroy: function (hv) {
        hv.vm.close()
    }
}
