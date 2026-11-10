var util = require('../../util')

/** @param {string} url */
function youtube_id(url) {
    var match = url.match(/(?:youtu\.be\/|youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|v\/))([^?&"'>]+)/)
    return match ? match[1] : null
}

/**
 * @param {string} type
 * @param {string} url
 */
function can(type, url) {
    if (type !== 'video' && type !== 'youtube') {
        return 0
    }
    if (url.length === 0) {
        return 1
    }
    return youtube_id(url) ? 100 : 0
}

/**
 * @param {HTMLElement} root
 * @param {string} type
 * @param {number} channel
 * @returns {import('../../types').Media}
 */
function init(root, type, channel) {
    var ready = false
    var iframe = document.createElement('iframe')
    iframe.className = 'youtube-player'
    iframe.setAttribute('frameborder', '0')
    iframe.setAttribute('allow', 'autoplay encrypted-media')
    iframe.style.zIndex = String(-channel - 1)
    iframe.addEventListener('load', function () {
        ready = true
    })
    root.appendChild(iframe)

    /**
     * @param {string} func
     * @param {any[]} [args]
     */
    function command(func, args) {
        if (!ready) {
            return setTimeout(function () {
                command(func, args)
            }, 100)
        }
        if (iframe.contentWindow) {
            iframe.contentWindow.postMessage(JSON.stringify({event: 'command', func: func, args: args || []}), '*')
        }
    }

    return {
        set_time: function (time) {
            command('seekTo', [time, true])
        },
        source: function (url) {
            ready = false
            iframe.src = 'https://www.youtube.com/embed/' + youtube_id(url) + '?enablejsapi=1&autoplay=0&modestbranding=1&controls=0'
        },
        play: function () {
            command('playVideo')
        },
        pause: function () {
            command('pauseVideo')
        },
        resume: function () {
            command('playVideo')
        },
        position: function (x, y, w, h) {
            util.place(iframe, x, y, w, h)
        },
        destroy: function () {
            iframe.remove()
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
