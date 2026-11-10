var util = require('../../util')

/**
 * @param {string} type
 * @param {string} url
 * @param {number} score
 */
function can(type, url, score) {
    if (type !== 'video' && type !== 'stream') {
        return 0
    }
    return score + (/\.(m3u8|mpd)$/i.test(url) ? 40 : 20)
}

/**
 * @param {any} videojs
 * @param {HTMLElement} root
 * @param {string} type
 * @param {number} channel
 * @returns {import('../../types').Media}
 */
function init(videojs, root, type, channel) {
    var el = document.createElement('video')
    el.className = 'video-js'
    el.style.zIndex = String(-channel - 1)
    root.appendChild(el)

    if (!document.getElementById('vsj-hidden')) {
        var style = document.createElement('style')
        style.id = 'vsj-hidden'
        style.textContent = '.vsj-hidden, .video-js div, .video-js button { display: none }'
        document.head.appendChild(style)
    }

    var player = videojs(el, {controls: false})

    return {
        set_time: function (time) {
            player.currentTime(time)
        },
        source: function (url) {
            player.src({src: url})
        },
        play: function () {
            player.currentTime(0)
            player.play()
        },
        pause: function () {
            player.pause()
        },
        resume: function () {
            player.play()
        },
        position: function (x, y, w, h) {
            player.width(w)
            player.height(h)
            util.place(el, x, y, w, h)
        },
        destroy: function () {
            player.dispose()
            el.remove()
        }
    }
}

/** @type {import('../../types').Driver} */
module.exports = {
    /** @param {any} videojs the `window.videojs` library, skipped when missing */
    prepare: function (hv, videojs) {
        if (videojs) {
            hv.players.push({can: can, init: function (type, channel) {
                return init(videojs, hv.root, type, channel)
            }})
        }
    }
}
