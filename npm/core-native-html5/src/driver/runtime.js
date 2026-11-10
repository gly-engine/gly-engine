/** @type {import('../types').Driver} */
var runtime = {
    /**
     * @param {{uptime?: boolean, unfocus_pause?: boolean}} [cfg]
     * uptime sends total time instead of delta, unfocus_pause pauses when window loses focus.
     */
    startup: async function (hv, cfg) {
        cfg = cfg || {}
        var last = performance.now()

        function tick() {
            if (!hv.running) {
                return
            }
            var now = performance.now()
            hv.frontend.native_callback_loop(cfg && cfg.uptime ? now : now - last)
            hv.frontend.native_callback_draw()
            last = now
            window.requestAnimationFrame(tick)
        }

        if (cfg.unfocus_pause) {
            hv.listen(window, 'blur', function () {
                hv.pause('focus')
            })
            hv.listen(window, 'focus', function () {
                hv.resume('focus')
            })
        }

        await new Promise(function (resolve) {
            setTimeout(resolve, 1)
        })

        window.requestAnimationFrame(function () {
            hv.frontend.native_callback_init()
            tick()
        })
    }
}

/** @type {import('../types').Driver} */
var resize = {
    /**
     * @param {{widescreen?: boolean}} [cfg] widescreen uses half height when in portrait.
     */
    startup: function (hv, cfg) {
        var widescreen = !cfg || cfg.widescreen !== false
        function fit() {
            var width = window.innerWidth
            var height = window.innerHeight
            hv.frontend.native_callback_resize(width, widescreen && height >= width ? height / 2 : height)
        }
        hv.listen(window, 'resize', fit)
        fit()
    }
}

module.exports = {
    runtime: runtime,
    resize: resize
}
