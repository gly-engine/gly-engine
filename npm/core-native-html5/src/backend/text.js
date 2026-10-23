var LOADING = 0
var READY = 1
var ERROR = 2

/**
 * fonts follow core-native: registered by url with `native_text_font_face(name, url)`,
 * selected by family name, invisible until loaded.
 * @param {import('../types').Render} render
 */
module.exports = function (render) {
    var ctx = render.ctx
    /** @type {Array<{family: string, state: number}>} */
    var fonts = [{family: 'sans-serif', state: READY}]
    /** @type {Record<string, number>} */
    var by_url = {}
    /** @type {Record<string, number>} */
    var by_family = {'default': 0}
    var current = 0
    var size = 16
    var previous = [0, 16]
    var applied = ''

    /** @param {number} id */
    function ready(id) {
        return fonts[id].state === READY
    }

    function apply() {
        var font = size + 'px "' + fonts[current].family + '"'
        if (font !== applied) {
            applied = ctx.font = font
            ctx.textBaseline = 'top'
            ctx.textAlign = 'left'
        }
    }

    /**
     * @param {string} family
     * @param {string} url
     * @param {{state: number}} font
     */
    function load(family, url, font) {
        var src = 'url("' + url + '")'
        if (typeof FontFace == 'undefined') {
            var style = document.createElement('style')
            style.textContent = '@font-face { font-family: "' + family + '"; src: ' + src + '; }'
            document.head.appendChild(style)
            font.state = READY
            return
        }
        new FontFace(family, src).load().then(function (face) {
            /** @type {any} */ (document.fonts).add(face)
            font.state = READY
        }, function (err) {
            font.state = ERROR
            console.error('[core:html5] font "' + url + '" ' + err)
        })
    }

    return {
        /**
         * @param {string} name family
         * @param {string} url
         * @returns {number} font id
         */
        native_text_font_face: function (name, url) {
            var id = by_url[url]
            if (id === undefined) {
                var font = {family: name, state: LOADING}
                id = by_url[url] = fonts.push(font) - 1
                load(name, url, font)
            }
            by_family[name] = id
            return id
        },
        /** @param {string} name family, unknown keeps current font */
        native_text_font_name: function (name) {
            if (by_family.hasOwnProperty(name)) {
                previous = [current, size]
                current = by_family[name]
            }
        },
        native_text_font_default: function () {
            previous = [current, size]
            current = 0
        },
        /** @param {number} value */
        native_text_font_size: function (value) {
            previous = [current, size]
            size = Math.floor(value) || 16
        },
        /** @todo remove together with std.text.put */
        native_text_font_previous: function () {
            var font = previous
            previous = [current, size]
            current = font[0]
            size = font[1]
        },
        /**
         * @param {number} x
         * @param {number} y
         * @param {string} text
         */
        native_text_print: function (x, y, text) {
            if (ready(current)) {
                apply()
                ctx.fillText(String(text), x, y)
            }
        },
        /**
         * @param {string} text
         * @returns {number[]} width, height
         */
        native_text_mensure: function (text) {
            if (!ready(current)) {
                return [0, 0]
            }
            apply()
            var m = ctx.measureText(String(text))
            return [m.width, (m.actualBoundingBoxAscent + m.actualBoundingBoxDescent) || size]
        }
    }
}
