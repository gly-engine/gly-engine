/**
 * @typedef {{canvas: HTMLCanvasElement, ctx: CanvasRenderingContext2D}} Render
 */

/**
 * @typedef {Object} Bus
 * @property {(event: string, listener: Function) => void} on
 * @property {(event: string, ...args: any[]) => void} emit
 * @property {() => void} clear
 */

/**
 * @typedef {Object} Media
 * @property {() => void} play
 * @property {() => void} pause
 * @property {() => void} resume
 * @property {() => void} destroy
 * @property {(url: string) => void} source
 * @property {(x: number, y: number, w: number, h: number) => void} position
 * @property {(time: number) => void} set_time
 */

/**
 * score returned by `can` decides which player handles a channel, 0 means unsupported.
 * @typedef {Object} Player
 * @property {(type: string, url: string, score: number) => number} can
 * @property {(type: string, channel: number) => Media} init
 */

/**
 * @typedef {Object} Hypervisor
 * @property {HTMLCanvasElement} canvas
 * @property {CanvasRenderingContext2D} ctx
 * @property {HTMLElement} root
 * @property {{engine: () => Promise<string>, game?: string}} code
 * @property {Bus} bus
 * @property {Player[]} players
 * @property {Record<string, any>} backend
 * @property {Record<string, Function>} frontend
 * @property {Record<string, any>} vm lua drivers set `call(name, args)` to receive engine callbacks and `close()`
 * @property {boolean} running
 * @property {(motive?: string) => void} pause
 * @property {(motive?: string) => void} resume
 * @property {() => boolean} paused
 * @property {(target: EventTarget, event: string, listener: EventListener) => void} listen
 */

/**
 * every step is optional and receives the arguments given to `.use()`.
 * @typedef {Object} Driver
 * @property {(hv: Hypervisor, ...args: any[]) => any} [prepare]
 * @property {(hv: Hypervisor, ...args: any[]) => any} [install]
 * @property {(hv: Hypervisor, ...args: any[]) => any} [startup]
 * @property {(hv: Hypervisor, ...args: any[]) => any} [destroy]
 */

/**
 * running instance returned by `build()`.
 * @typedef {Object} Gly
 * @property {HTMLCanvasElement} canvas
 * @property {CanvasRenderingContext2D} ctx
 * @property {Record<string, any>} backend every `native_*` given to the engine
 * @property {Record<string, Function>} frontend every `native_callback_*`
 * @property {() => boolean} paused
 * @property {(motive?: string) => Gly} pause
 * @property {(motive?: string) => Gly} resume without motive resume all
 * @property {(event: string, listener: Function) => Gly} on init, loop, draw, resize, keyboard
 * @property {() => Promise<void>} destroy
 */

/**
 * @typedef {Object} Builder
 * @property {(name: string | Driver, ...args: any[]) => Builder} use canvas, root, engine, game or driver
 * @property {() => Promise<Gly>} build
 */

module.exports = {}
