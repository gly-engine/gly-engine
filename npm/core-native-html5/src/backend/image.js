var LOADING = 0
var READY = 1
var ERROR = 2

/**
 * images follow core-native: `load(url)` returns an id (> 0, never reused) and fetch in background,
 * every function accepts id or url, draw/mensure do nothing until ready.
 * @param {import('../types').Render} render
 */
module.exports = function (render) {
    var ctx = render.ctx
    var next_id = 0
    /** @typedef {{url: string, el: HTMLImageElement, state: number, error?: string}} Image */
    /** @type {Record<number, Image>} */
    var images = {}
    /** @type {Record<string, number>} */
    var by_url = {}

    /**
     * @param {string} url
     * @returns {number} id or -1 when invalid
     */
    function load(url) {
        if (!url) {
            return -1
        }
        if (by_url[url]) {
            return by_url[url]
        }
        var id = by_url[url] = ++next_id
        var el = document.createElement('img')
        /** @type {Image} */
        var image = images[id] = {url: url, el: el, state: LOADING}
        /** @param {string} reason */
        function fail(reason) {
            image.state = ERROR
            image.error = 'image "' + url + '" ' + reason
        }
        el.onload = function () {
            image.state = READY
        }
        el.onerror = function () {
            fail('error')
        }
        el.onabort = function () {
            fail('abort')
        }
        el.src = url
        return id
    }

    /** @param {number | string} src */
    function id_of(src) {
        return typeof src == 'number' ? src : load(src)
    }

    /** @param {number | string} src */
    function ready(src) {
        var image = images[id_of(src)]
        return image && image.state === READY ? image : null
    }

    /** @param {number} id */
    function unload(id) {
        var image = images[id]
        if (image) {
            image.el.onload = image.el.onerror = image.el.onabort = null
            delete by_url[image.url]
            delete images[id]
        }
    }

    return {
        native_image_load: load,
        /** @param {number | string} src */
        native_image_exists: function (src) {
            return !!ready(src)
        },
        /**
         * @param {number | string} src
         * @param {number} x
         * @param {number} y
         * @returns {number} id
         */
        native_image_draw: function (src, x, y) {
            var image = ready(src)
            if (image) {
                ctx.drawImage(image.el, x, y)
            }
            return id_of(src)
        },
        /**
         * @param {number | string} src
         * @returns {number[]} width, height
         */
        native_image_mensure: function (src) {
            var image = ready(src)
            return image ? [image.el.width, image.el.height] : [0, 0]
        },
        /** @param {number | string} src */
        native_image_error: function (src) {
            var image = images[id_of(src)]
            return image && image.error
        },
        /** @param {number | string} src url unloads without loading */
        native_image_unload: function (src) {
            unload(typeof src == 'string' ? by_url[src] : src)
        },
        native_image_unload_all: function () {
            for (var id in images) {
                unload(Number(id))
            }
        },
        native_image_loading_count: function () {
            var count = 0
            for (var id in images) {
                count += images[id].state === LOADING ? 1 : 0
            }
            return count
        }
    }
}
