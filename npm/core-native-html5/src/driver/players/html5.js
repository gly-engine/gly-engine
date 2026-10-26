var util = require('../../util')

/**
 * @param {string} type
 * @param {string} url
 * @param {number} score
 */
function can(type, url, score) {
    return ['video', 'audio', 'music', 'sfx'].indexOf(type) === -1 ? 0 : score + 20
}

/**
 * @param {HTMLElement} root
 * @param {string} type
 * @param {number} channel
 * @returns {import('../../types').Media}
 */
function init(root, type, channel) {
    var video = type === 'video'
    var el = document.createElement(video ? 'video' : 'audio')
    el.style.zIndex = String(-channel - 1)
    root.appendChild(el)

    /** @param {number} time */
    function set_time(time) {
        if (el.fastSeek) {
            el.fastSeek(time)
        } else {
            el.currentTime = time
        }
    }

    return {
        set_time: set_time,
        source: function (url) {
            el.src = url
        },
        play: function () {
            set_time(0)
            el.play()
        },
        pause: function () {
            el.pause()
        },
        resume: function () {
            el.play()
        },
        position: function (x, y, w, h) {
            if (video) {
                util.place(el, x, y, w, h)
            }
        },
        destroy: function () {
            el.pause()
            el.removeAttribute('src')
            el.load()
            el.remove()
        }
    }
}

/** @type {import('../../types').Driver} */
module.exports = {
    prepare: function (hv) {
        hv.players.push({can: can, init: function (type, channel) {
            return init(hv.root, type, channel)
        }})
    }
}
