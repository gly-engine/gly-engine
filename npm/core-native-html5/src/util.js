/**
 * @param {Array<Record<string, any>>} list
 * @returns {Record<string, any>} new object with keys of all objects in list
 */
function merge(list) {
    /** @type {Record<string, any>} */
    var out = {}
    for (var i = 0; i < list.length; i++) {
        for (var key in list[i]) {
            out[key] = list[i][key]
        }
    }
    return out
}

/**
 * @param {ArrayLike<any>} list
 * @param {number} [start]
 * @returns {any[]}
 */
function slice(list, start) {
    return Array.prototype.slice.call(list, start)
}

/**
 * @param {HTMLElement} el
 * @param {number} x
 * @param {number} y
 * @param {number} w
 * @param {number} h
 */
function place(el, x, y, w, h) {
    el.style.left = x + 'px'
    el.style.top = y + 'px'
    el.style.width = w + 'px'
    el.style.height = h + 'px'
}

/**
 * @param {string | HTMLElement | undefined} el
 * @returns {HTMLElement | null}
 */
function element(el) {
    return typeof el == 'string' ? document.querySelector(el) : el || null
}

/**
 * load source code from url or inline text (has a line break).
 * @param {string} name
 * @param {string | undefined} src
 */
async function code(name, src) {
    if (!src) {
        throw new Error('missing code: ' + name)
    }
    if (src.indexOf('\n') !== -1) {
        return src.replace(/\0/g, '')
    }
    var response = await fetch(src)
    if (!response.ok) {
        throw new Error(response.status + ' code: ' + name)
    }
    return response.text()
}

module.exports = {
    merge: merge,
    slice: slice,
    place: place,
    element: element,
    code: code
}
