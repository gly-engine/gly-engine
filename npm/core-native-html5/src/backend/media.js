/**
 * each channel is bootstraped with a media type, the player with the best score handles its source.
 * @param {import('../types').Player[]} players
 */
module.exports = function (players) {
    /** @type {string[]} */
    var devices = []
    /** @type {Array<import('../types').Player | undefined>} */
    var current = []
    /** @type {Array<import('../types').Media | null>} */
    var mixer = []

    /**
     * @param {string} method
     * @returns {(channel: number, a?: number, b?: number, c?: number, d?: number) => void}
     */
    function forward(method) {
        return function (channel, a, b, c, d) {
            var media = /** @type {any} */ (mixer[channel])
            if (media) {
                media[method](a, b, c, d)
            }
        }
    }

    /** @param {number} channel */
    function stop(channel) {
        var media = mixer[channel]
        mixer[channel] = null
        if (media) {
            media.destroy()
        }
    }

    return {
        /**
         * @param {string} type
         * @returns {number} 1 when any player supports the type
         */
        native_media_bootstrap: function (type) {
            var support = 0
            for (var i = 0; i < players.length; i++) {
                support = support || (players[i].can(type, '', 1) ? 1 : 0)
            }
            mixer[devices.push(type) - 1] = null
            return support
        },
        /**
         * @param {number} channel
         * @param {string} url
         */
        native_media_source: function (channel, url) {
            var type = devices[channel]
            var best = null
            var best_score = 0
            for (var i = 0; i < players.length; i++) {
                var score = players[i].can(type, url, players[i] === current[channel] ? 20 : players.length - i)
                if (score > best_score) {
                    best = players[i]
                    best_score = score
                }
            }
            if (best_score <= 10 || best !== current[channel]) {
                stop(channel)
            }
            if (!mixer[channel] && best && best_score > 10) {
                mixer[channel] = best.init(type, channel)
                current[channel] = best
            }
            if (!mixer[channel]) {
                console.error('unsupported media: channel ' + channel + ' type ' + type + '\n' + url)
                return
            }
            mixer[channel].source(url)
        },
        native_media_position: forward('position'),
        native_media_play: forward('play'),
        native_media_resume: forward('resume'),
        native_media_pause: forward('pause'),
        native_media_time: forward('set_time'),
        native_media_stop: stop
    }
}
