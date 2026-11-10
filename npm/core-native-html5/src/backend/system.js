/**
 * @param {import('../types').Hypervisor} hv
 */
module.exports = function (hv) {
    /**
     * same protocol of core-native, request data is pulled from `native_callback_http`.
     * @param {any} _
     * @param {number} id
     */
    function native_http_handler(_, id) {
        /**
         * @param {string} key
         * @param {any} [data]
         */
        function http(key, data) {
            return hv.vm.call('native_callback_http', [id, key, data])
        }
        var method = http('get-method')
        http('async-promise')
        fetch(http('get-fullurl'), {
            method: method,
            body: method === 'GET' || method === 'HEAD' ? null : http('get-body')
        }).then(function (response) {
            http('set-status', response.status)
            return response.text()
        }).then(function (body) {
            http('set-body', body)
            http('async-resolve')
        }, function (error) {
            http('set-ok', false)
            http('set-error', String(error))
            http('async-resolve')
        })
    }

    /** @param {(text: string) => void} log */
    function logger(log) {
        return function (/** @type {string} */ text) {
            log.call(console, text)
        }
    }

    return {
        native_http_handler: native_http_handler,
        native_http_has_ssl: true,
        native_http_has_callback: true,
        native_http_force_protocol: location.protocol === 'https:' ? 'https' : undefined,
        native_system_get_language: function () {
            return navigator.language
        },
        /**
         * variables come from url hash, `#lang=pt&debug=1`
         * @param {string} name
         */
        native_system_get_env: function (name) {
            return new URLSearchParams(location.hash.substring(1)).get(name) || undefined
        },
        native_log_debug: logger(console.log),
        native_log_trace: logger(console.info),
        native_log_info: logger(console.info),
        native_log_warn: logger(console.warn),
        native_log_error: logger(console.error),
        native_log_fatal: logger(console.error)
    }
}
