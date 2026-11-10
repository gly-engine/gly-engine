/**
 * @param {number} color 0xRRGGBBAA
 */
function rgba(color) {
    var a = (color & 0xFF) / 255
    return 'rgba(' + ((color >>> 24) & 0xFF) + ',' + ((color >>> 16) & 0xFF) + ',' + ((color >>> 8) & 0xFF) + ',' + a.toFixed(3) + ')'
}

/**
 * @param {import('../types').Render} render
 */
module.exports = function (render) {
    var canvas = render.canvas
    var ctx = render.ctx

    /** @param {number} mode 0 fill, 1 stroke */
    function paint(mode) {
        if (mode === 1) {
            ctx.stroke()
        } else {
            ctx.fill()
        }
    }

    /**
     * @param {number} mode
     * @param {number} x
     * @param {number} y
     * @param {number} w
     * @param {number} h
     */
    function rect(mode, x, y, w, h) {
        if (mode === 1) {
            ctx.strokeRect(x, y, w, h)
        } else {
            ctx.fillRect(x, y, w, h)
        }
    }

    /**
     * @param {number} mode 0 fill, 1 closed line, 2 open line
     * @param {number[]} verts
     * @param {number} x
     * @param {number} y
     * @param {number} scale
     * @param {number} angle
     * @param {number} ox
     * @param {number} oy
     */
    function poly2(mode, verts, x, y, scale, angle, ox, oy) {
        var cos = -scale * Math.cos(angle)
        var sin = -scale * Math.sin(angle)
        ctx.beginPath()
        for (var i = 0; i < verts.length; i += 2) {
            var px = verts[i]
            var py = verts[i + 1]
            var xx = x + ((ox - px) * cos) - ((oy - py) * sin)
            var yy = y + ((oy - px) * sin) + ((ox - py) * cos)
            if (i === 0) {
                ctx.moveTo(xx, yy)
            } else {
                ctx.lineTo(xx, yy)
            }
        }
        if (mode === 1) {
            ctx.closePath()
        }
        paint(mode === 0 ? 0 : 1)
    }

    return {
        native_draw_start: function () {
            ctx.clearRect(0, 0, canvas.width, canvas.height)
        },
        native_draw_flush: function () {},
        /**
         * @param {number} color
         * @param {number} [x]
         * @param {number} [y]
         * @param {number} [w]
         * @param {number} [h]
         */
        native_draw_clear: function (color, x, y, w, h) {
            ctx.fillStyle = rgba(color)
            ctx.fillRect(x || 0, y || 0, w || canvas.width, h || canvas.height)
        },
        /** @param {number} color */
        native_draw_color: function (color) {
            ctx.strokeStyle = ctx.fillStyle = rgba(color)
        },
        /**
         * @param {number} x1
         * @param {number} y1
         * @param {number} x2
         * @param {number} y2
         */
        native_draw_line: function (x1, y1, x2, y2) {
            ctx.beginPath()
            ctx.moveTo(x1, y1)
            ctx.lineTo(x2, y2)
            ctx.stroke()
        },
        native_draw_rect: rect,
        /**
         * @param {number} mode
         * @param {number} x
         * @param {number} y
         * @param {number} w
         * @param {number} h
         * @param {number} [r] corner radius
         */
        native_draw_rect2: function (mode, x, y, w, h, r) {
            if (!r) {
                return rect(mode, x, y, w, h)
            }
            r = Math.min(r, w / 2, h / 2)
            ctx.beginPath()
            ctx.moveTo(x + r, y)
            ctx.arc(x + w - r, y + r, r, 1.5 * Math.PI, 0)
            ctx.arc(x + w - r, y + h - r, r, 0, 0.5 * Math.PI)
            ctx.arc(x + r, y + h - r, r, 0.5 * Math.PI, Math.PI)
            ctx.arc(x + r, y + r, r, Math.PI, 1.5 * Math.PI)
            ctx.closePath()
            paint(mode)
        },
        native_draw_poly2: poly2,
        /**
         * @param {number} mode
         * @param {number[]} verts
         * @param {number} [x]
         * @param {number} [y]
         * @param {number} [scale]
         * @param {number} [angle]
         * @param {number} [ox]
         * @param {number} [oy]
         */
        native_draw_poly: function (mode, verts, x, y, scale, angle, ox, oy) {
            poly2(mode, verts, x || 0, y || 0, scale === undefined ? 1 : scale, angle || 0, ox || 0, oy || 0)
        }
    }
}
