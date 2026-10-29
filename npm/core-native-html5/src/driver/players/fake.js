var draw = require('../../backend/draw')

/**
 * clock hand sweeping the screen border once per second.
 * @param {number} ms
 * @param {number} width
 * @param {number} height
 */
function sweep(ms, width, height) {
    var points = [[width / 2, 0], [width, 0], [width, height], [0, height], [0, 0], [width / 2, 0]]
    var segment = 1000 / (points.length - 1)
    var step = Math.min(Math.floor(ms / segment), points.length - 2)
    var t = (ms % segment) / segment
    var verts = [width / 2, height / 2]
    for (var i = 0; i <= step; i++) {
        verts.push(points[i][0], points[i][1])
    }
    var from = points[step]
    var to = points[step + 1]
    verts.push(from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t)
    return verts
}

/** @param {number} ms */
function chronometer(ms) {
    var millis = String(Math.floor(ms % 1000))
    return new Date(ms).toISOString().substr(11, 8) + ':' + '000'.substring(millis.length) + millis
}

/**
 * fake video player drawn in a canvas, for testing without real media.
 * @param {HTMLElement} root
 * @param {string} type
 * @param {number} channel
 * @returns {import('../../types').Media}
 */
function init(root, type, channel) {
    var el = document.createElement('canvas')
    var ctx = /** @type {CanvasRenderingContext2D} */ (el.getContext('2d'))
    var backend = draw({canvas: el, ctx: ctx})
    var src = ''
    var cmd = 'init'
    var paused = true
    var started = performance.now()

    el.width = root.clientWidth
    el.height = root.clientHeight
    el.style.zIndex = String(-channel - 1)
    root.appendChild(el)

    /**
     * @param {number} size
     * @param {CanvasTextBaseline} baseline
     * @param {CanvasTextAlign} align
     * @param {string} text
     * @param {number} x
     * @param {number} y
     */
    function text(size, baseline, align, text, x, y) {
        ctx.font = Math.round(size) + 'px sans'
        ctx.textBaseline = baseline
        ctx.textAlign = align
        ctx.fillText(text, x, y)
    }

    function tick() {
        if (!el.parentElement) {
            return
        }
        var w = el.width
        var h = el.height
        var uptime = performance.now() - started
        var secs = Math.ceil(uptime / 1000)
        backend.native_draw_clear(secs & 1 ? 0x000000FF : 0x222222FF)
        backend.native_draw_color(secs & 1 ? 0x222222FF : 0x000000FF)
        backend.native_draw_poly2(0, sweep(uptime % 1000, w, h), 0, 0, 1, 0, 0, 0)
        backend.native_draw_color(0x333333FF)
        backend.native_draw_line(0, h / 2, w, h / 2)
        backend.native_draw_line(w / 2, 0, w / 2, h)
        backend.native_draw_color(0xFFFFFFFF)
        text(w / 80, 'top', 'left', type, 0, 0)
        text(w / 80, 'bottom', 'left', cmd, 0, h)
        text(w / 80, 'bottom', 'right', src, w, h)
        text(w / 80, 'top', 'right', chronometer(uptime), w, 0)
        text(w / 16, 'middle', 'center', String(secs), w / 2, h / 2)
        if (!paused) {
            window.requestAnimationFrame(tick)
        }
    }

    /** @param {string} name */
    function run(name) {
        cmd = name
        if (paused) {
            paused = false
            tick()
        }
    }

    return {
        set_time: function (time) {
            started = Math.max(0, performance.now() - time)
        },
        source: function (url) {
            cmd = 'source'
            src = url
        },
        play: function () {
            started = performance.now()
            run('play')
        },
        resume: function () {
            run('resume')
        },
        pause: function () {
            cmd = 'pause'
            paused = true
        },
        position: function (x, y, w, h) {
            cmd = 'position'
            el.style.left = x + 'px'
            el.style.top = y + 'px'
            el.width = w
            el.height = h
        },
        destroy: function () {
            el.remove()
        }
    }
}

/** @type {import('../../types').Driver} */
module.exports = {
    /** @param {number} [score] priority over other players, default 11 */
    prepare: function (hv, score) {
        var bonus = typeof score == 'number' ? score : 11
        hv.players.push({
            can: function (type, url, base) {
                return ['video', 'tv', 'youtube', 'stream'].indexOf(type) === -1 ? 0 : base + bonus
            },
            init: function (type, channel) {
                return init(hv.root, type, channel)
            }
        })
    }
}
