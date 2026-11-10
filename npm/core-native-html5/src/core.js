var util = require('./util')
var backend = require('./backend')

/** engine callbacks, each one is `native_callback_<event>` in the lua side */
var EVENTS = ['init', 'loop', 'draw', 'resize', 'keyboard']

/** @returns {import('./types').Bus} */
function bus() {
    /** @type {Record<string, Function[]>} */
    var events = {}
    return {
        on: function (event, listener) {
            (events[event] = events[event] || []).push(listener)
        },
        emit: function (event) {
            var listeners = events[event] || []
            var args = util.slice(arguments, 1)
            for (var i = 0; i < listeners.length; i++) {
                listeners[i].apply(null, args)
            }
        },
        clear: function () {
            events = {}
        }
    }
}

/**
 * @param {import('./types').Hypervisor} hv
 */
function frontend(hv) {
    var started = false
    /** @type {ReturnType<typeof setInterval> | undefined} */
    var waiting

    /** @param {string} event */
    function unpaused(event) {
        return function (/** @type {any} */ a, /** @type {any} */ b) {
            if (!hv.paused()) {
                hv.bus.emit(event, a, b)
            }
        }
    }

    return {
        /**
         * @param {number} [width]
         * @param {number} [height]
         */
        native_callback_init: function (width, height) {
            started = true
            hv.bus.emit('init', width || hv.canvas.width, height || hv.canvas.height, hv.code.game)
        },
        /** @param {number} [dt] milliseconds */
        native_callback_loop: function (dt) {
            if (!hv.paused()) {
                hv.bus.emit('pad')
                hv.bus.emit('loop', dt || 16)
            }
        },
        native_callback_draw: unpaused('draw'),
        native_callback_keyboard: unpaused('keyboard'),
        /**
         * resize while paused is delivered when resumed.
         * @param {number} width
         * @param {number} height
         */
        native_callback_resize: function (width, height) {
            hv.canvas.width = width
            hv.canvas.height = height
            clearInterval(waiting)
            if (!started) {
                return
            }
            if (!hv.paused()) {
                return hv.bus.emit('resize', width, height)
            }
            waiting = setInterval(function () {
                if (!hv.paused()) {
                    clearInterval(waiting)
                    hv.bus.emit('resize', width, height)
                }
            }, 100)
        }
    }
}

/**
 * @typedef {Object} Config
 * @property {string | HTMLCanvasElement} [canvas]
 * @property {string | HTMLElement} [root] where media players are placed
 * @property {string} [engine] url or lua code
 * @property {string} [game] url or lua code
 */

/**
 * @param {Config} cfg
 * @param {Array<{driver: import('./types').Driver, args: any[]}>} libs
 */
async function build(cfg, libs) {
    var canvas = /** @type {HTMLCanvasElement | null} */ (util.element(cfg.canvas))
    if (cfg.canvas && !canvas) {
        throw new Error('element dont exist: ' + cfg.canvas)
    }
    canvas = canvas || document.createElement('canvas')
    /** @type {Array<[EventTarget, string, EventListener]>} */
    var listeners = []
    /** @type {Record<string, boolean>} */
    var reasons = {}

    /** @type {import('./types').Hypervisor} */
    var hv = {
        canvas: canvas,
        ctx: /** @type {CanvasRenderingContext2D} */ (canvas.getContext('2d')),
        root: util.element(cfg.root) || canvas.parentElement || document.body,
        code: {
            engine: function () {
                return util.code('engine', cfg.engine)
            },
            game: cfg.game ? await util.code('game', cfg.game) : undefined
        },
        bus: bus(),
        players: [],
        backend: {},
        frontend: {},
        vm: {},
        running: true,
        pause: function (motive) {
            reasons[motive || 'pause'] = true
        },
        resume: function (motive) {
            if (motive) {
                reasons[motive] = false
            } else {
                reasons = {}
            }
        },
        paused: function () {
            for (var motive in reasons) {
                if (reasons[motive]) {
                    return true
                }
            }
            return false
        },
        listen: function (target, event, listener) {
            target.addEventListener(event, listener)
            listeners.push([target, event, listener])
        }
    }

    hv.backend = backend(hv)
    hv.frontend = frontend(hv)

    /** @param {'prepare' | 'install' | 'startup' | 'destroy'} name */
    function step(name) {
        return Promise.all(libs.map(function (lib) {
            var func = lib.driver[name]
            return func && func.apply(lib.driver, /** @type {any} */ ([hv]).concat(lib.args))
        }))
    }

    await step('prepare')
    await step('install')

    if (hv.vm.call) {
        EVENTS.forEach(function (event) {
            hv.bus.on(event, function () {
                hv.vm.call('native_callback_' + event, util.slice(arguments))
            })
        })
    }

    await step('startup')

    /** @type {import('./types').Gly} */
    var self = {
        canvas: hv.canvas,
        ctx: hv.ctx,
        backend: hv.backend,
        frontend: hv.frontend,
        paused: hv.paused,
        /** @param {string} [motive] */
        pause: function (motive) {
            hv.pause(motive)
            return self
        },
        /** @param {string} [motive] without motive resume all */
        resume: function (motive) {
            hv.resume(motive)
            return self
        },
        /**
         * @param {string} event init, loop, draw, resize, keyboard
         * @param {Function} listener
         */
        on: function (event, listener) {
            hv.bus.on(event, listener)
            return self
        },
        destroy: async function () {
            hv.running = false
            await step('destroy')
            listeners.forEach(function (l) {
                l[0].removeEventListener(l[1], l[2])
            })
            hv.backend.native_image_unload_all()
            hv.bus.clear()
            hv.ctx.clearRect(0, 0, hv.canvas.width, hv.canvas.height)
        }
    }

    return self
}

/**
 * @param {Record<string, import('./types').Driver>} drivers built-in drivers
 */
module.exports = function (drivers) {
    /**
     * `.use(name, ...args)` sets canvas, root, engine and game, or adds a driver by name or object.
     * @returns {import('./types').Builder}
     */
    return function CoreNativeHtml5() {
        /** @type {Config & Record<string, any>} */
        var cfg = {canvas: undefined, root: undefined, engine: undefined, game: undefined}
        /** @type {Array<{driver: import('./types').Driver, args: any[]}>} */
        var libs = []
        /** @type {import('./types').Builder} */
        var self = {
            /**
             * @param {string | import('./types').Driver} name
             * @param {...any} args
             */
            use: function (name, args) {
                args = util.slice(arguments, 1)
                if (typeof name == 'string' && cfg.hasOwnProperty(name)) {
                    cfg[name] = args[0]
                    return self
                }
                var driver = typeof name == 'string' ? drivers[name] : name
                if (!driver) {
                    throw new Error('driver not found: ' + name)
                }
                libs.push({driver: driver, args: args})
                return self
            },
            build: function () {
                return build(cfg, libs)
            }
        }
        return self
    }
}
