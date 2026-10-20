# core-native-html5

[![npm](https://img.shields.io/npm/dy/@gamely/core-native-html5?logo=npm&logoColor=fff&label=npm%20downloads)](https://www.npmjs.com/package/@gamely/core-native-html5)
[![cdn](https://img.shields.io/jsdelivr/npm/hy/@gamely/core-native-html5?logo=jsdelivr&logoColor=fff&label=cdn%20downloads)](https://www.jsdelivr.com/package/npm/@gamely/core-native-html5)

> create your own game-engine with just javascript or lua.

Written in ES5 (plus `async`/`await`) with JSDoc types, no transpiler.
Bundled by the gly-cli itself, `gly-cli build --core html5` emits its own `core-native.js`.

## Bundles

| file              | content |
| :---------------- | :------ |
| `dist/index.js`   | every driver, global `CoreNativeHtml5`
| `dist/fengari.js` | only fengari lua vm, global `CoreNativeHtml5`
| `dist/wasmoon.js` | only wasmoon lua vm, global `CoreNativeHtml5`
| `dist/index.mjs`  | every driver, es module
| `dist/index.cjs.js` | every driver, commonjs

## Usage

`.use(name, ...args)` sets `canvas`, `root`, `engine`, `game` or adds a driver.

```js
const gly = await CoreNativeHtml5()
    .use('root', 'main')
    .use('canvas', '#gameCanvas')
    .use('wasmoon', LuaFactory, LuaMultiReturn)
    .use('runtime', {unfocus_pause: true})
    .use('keyboard')
    .use('resize')
    .use('engine', 'https://cdn.jsdelivr.net/npm/@gamely/gly-engine@latest/dist/main.lua')
    .use('game', 'game.lua')
    .build()
```

`engine` and `game` are urls, or lua code when they have a line break.

### Drivers

| driver          | arguments | description |
| :-------------- | :-------- | :---------- |
| fengari         | `fengari`, `json.lua url?` | lua vm in javascript, [rxi json.lua](https://cdn.jsdelivr.net/gh/rxi/json.lua/json.lua) gives `native_json_*`
| wasmoon         | `LuaFactory`, `LuaMultiReturn` | lua vm in webassembly
| runtime         | `{uptime?, unfocus_pause?}` | tick and draw events
| resize          | `{widescreen?}` | fit canvas to window
| keyboard        | `keymap or preset name?` | `[[code or keyCode, key], ...]`, presets `default` and `legacy`
| gamepad         | `padmap or preset name?` | `{pads: [...], axis: [...]}`, presets `default` and `legacy`
| player-html5    | | media using `<video>` and `<audio>`
| player-videojs  | `videojs` | media using videojs library
| player-youtube  | | media using youtube iframe
| player-fake     | `score?` | fake video player drawn in `<canvas>`

A driver is any object with optional async steps `prepare`, `install`, `startup` and `destroy`,
each one receives the hypervisor and the arguments of `.use()`.

```js
CoreNativeHtml5().use({startup: (hv, msg) => console.log(msg)}, 'hello')
```

### Instance

| method | description |
| :----- | :---------- |
| `pause(motive?)` / `resume(motive?)` / `paused()` | pause by motive, resume without motive clears all
| `on(event, listener)` | `init`, `loop`, `draw`, `resize`, `keyboard`
| `backend` | every `native_*` given to the engine
| `frontend` | every `native_callback_*`
| `canvas` / `ctx` | the canvas and its 2d context
| `destroy()` | stop drivers, remove listeners, clear canvas

### Images and fonts

Same contract of core-native desktop.

 * `native_image_load(url)` returns an id at once and loads in background, every image function accepts id or url,
   `draw`/`mensure` do nothing until ready, check with `native_image_exists`, `native_image_error` and `native_image_loading_count`.
 * `native_text_font_face(name, url)` registers a font (FontFace api), `native_text_font_name(name)` selects it,
   text is not drawn until the font is loaded. `native_text_font_default()` selects `default` (sans-serif).

### Third-party libraries

```html
<!-- fengari -->
<script src="https://cdn.jsdelivr.net/npm/fengari-web@latest/dist/fengari-web.min.js"></script>

<!-- wasmoon -->
<script type="module">
import { LuaFactory, LuaMultiReturn } from 'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/+esm'
window.LuaFactory = LuaFactory
window.LuaMultiReturn = LuaMultiReturn
</script>

<!-- videojs -->
<script src="https://cdn.jsdelivr.net/npm/video.js@8.22.0/dist/video.min.js"></script>
```

## Baremetal javascript

```js
const gly = await CoreNativeHtml5().use('canvas', '#gameCanvas').use('runtime').build()

gly.on('draw', () => {
    gly.backend.native_draw_color(0xFFFFFFFF)
    gly.backend.native_draw_rect(0, 50, 50, 50, 50)
})
```

## Development

```sh
npm run lint   # eslint, only ES5 syntax and async/await
npm run check  # tsc over JSDoc, only ES5 builtins
npm run build  # bundled by ../../cli.js bundler js
```
