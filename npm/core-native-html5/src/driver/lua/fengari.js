var util = require('../../util')

/**
 * lua 5.3 in pure javascript, https://github.com/fengari-lua/fengari-web
 * @type {import('../../types').Driver}
 */
module.exports = {
    /**
     * @param {any} fengari the `window.fengari` library
     * @param {string} [json] url or code of rxi json.lua, used as `native_json_*`
     */
    install: async function (hv, fengari, json) {
        if (!fengari) {
            throw new Error('fengari is required!')
        }

        var lua = fengari.lua
        var L = fengari.lauxlib.luaL_newstate()
        fengari.lualib.luaL_openlibs(L)

        /** @param {string} text */
        function str(text) {
            return fengari.to_luastring(text)
        }

        /**
         * lua value to javascript, tables become arrays.
         * @param {number} index
         * @returns {any}
         */
        function get(index) {
            switch (lua.lua_type(L, index)) {
                case lua.LUA_TNUMBER: return lua.lua_tonumber(L, index)
                case lua.LUA_TSTRING: return fengari.to_jsstring(lua.lua_tostring(L, index))
                case lua.LUA_TBOOLEAN: return lua.lua_toboolean(L, index)
                case lua.LUA_TTABLE: return list(lua.lua_absindex(L, index))
            }
        }

        /** @param {number} index */
        function list(index) {
            var out = []
            for (var n = 1; lua.lua_rawgeti(L, index, n) !== lua.LUA_TNIL; n++) {
                out.push(get(-1))
                lua.lua_pop(L, 1)
            }
            lua.lua_pop(L, 1)
            return out
        }

        /** @param {any} value */
        function push(value) {
            switch (typeof value) {
                case 'number': return (value | 0) === value ? lua.lua_pushinteger(L, value) : lua.lua_pushnumber(L, value)
                case 'string': return lua.lua_pushstring(L, str(value))
                case 'boolean': return lua.lua_pushboolean(L, value)
                default: return lua.lua_pushnil(L)
            }
        }

        /**
         * @param {string} name
         * @param {string} code
         * @param {number} results
         */
        function run(name, code, results) {
            var buffer = str(code)
            if (fengari.lauxlib.luaL_loadbuffer(L, buffer, buffer.length, str(name)) || lua.lua_pcall(L, 0, results, 0)) {
                throw new Error(get(-1))
            }
        }

        /**
         * @param {string} name
         * @param {any} value functions return arrays as multiple values
         */
        function global(name, value) {
            if (typeof value != 'function') {
                push(value)
                return lua.lua_setglobal(L, str(name))
            }
            lua.lua_pushcfunction(L, function () {
                var args = []
                for (var i = 1, top = lua.lua_gettop(L); i <= top; i++) {
                    args.push(get(i))
                }
                lua.lua_settop(L, 0)
                try {
                    var res = value.apply(null, args)
                } catch (e) {
                    lua.lua_pushstring(L, str(e + ' in ' + name))
                    return lua.lua_error(L)
                }
                res = res === undefined || res === null ? [] : Array.isArray(res) ? res : [res]
                res.forEach(push)
                return res.length
            })
            lua.lua_setglobal(L, str(name))
        }

        for (var key in hv.backend) {
            global(key, hv.backend[key])
        }

        if (json) {
            run('json.lua', await util.code('json.lua', json), 1)
            lua.lua_getfield(L, -1, str('encode'))
            lua.lua_setglobal(L, str('native_json_encode'))
            lua.lua_getfield(L, -1, str('decode'))
            lua.lua_setglobal(L, str('native_json_decode'))
            lua.lua_settop(L, 0)
        }

        run('engine', await hv.code.engine(), 0)

        hv.vm.close = function () {
            lua.lua_close(L)
        }
        hv.vm.call = function (/** @type {string} */ name, /** @type {any[]} */ args) {
            lua.lua_getglobal(L, str(name))
            args.forEach(push)
            if (lua.lua_pcall(L, args.length, 1, 0) !== 0) {
                var err = get(-1)
                lua.lua_settop(L, 0)
                throw new Error(err || name)
            }
            var res = get(-1)
            lua.lua_settop(L, 0)
            return res
        }
    },
    destroy: function (hv) {
        hv.vm.close()
    }
}
