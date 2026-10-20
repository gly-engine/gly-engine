# core-native-html5

[![npm](https://img.shields.io/npm/dy/@gamely/core-native-html5?logo=npm&logoColor=fff&label=npm%20downloads)](https://www.npmjs.com/package/@gamely/core-native-html5)
[![cdn](https://img.shields.io/jsdelivr/npm/hy/@gamely/core-native-html5?logo=jsdelivr&logoColor=fff&label=cdn%20downloads)](https://www.jsdelivr.com/package/npm/@gamely/core-native-html5)

> create your own game-engine with just javascript or lua.

### Built-in Modules

| driver name     | description |
| :-------------- | :---------- |
| fengari         | lua vm in es6
| wasmoon         | lua vm in wasm
| keyboard        | inputs events
| gamepad         | inputs events
| runtime         | tick and draw events
| resize          | auto resize width and height 
| player-fake     | fake video player using html element `<canvas>`
| player-html5    | video player using html  element `<video>`
| player-videojs  | video player using videojs library
| player-youtube  | video player using iframe youtube integration
| fengari-check   | check for a lua virtual machine<br/>_(also `wasmoon-check` `fengari-or-wasmoon-check`)_
| fengari-jsonrxi | thirdy party library json for core native api<br/>_(use string: <https://cdn.jsdelivr.net/gh/rxi/json.lua/json.lua>)_

### Third-party Libraries

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

## Gly Engine

replace `@latest` with the engine version you want.

 * <https://cdn.jsdelivr.net/npm/@gamely/gly-engine>
 * <https://cdn.jsdelivr.net/npm/@gamely/gly-engine-lite>
 * <https://cdn.jsdelivr.net/npm/@gamely/gly-engine-micro>
 * <https://cdn.jsdelivr.net/npm/@gamely/gly-engine-nano>

```js
const gly = await CoreNativeHtml5()
    .setElementRoot('main')
    .setElementCanvas('#gameCanvas')
    .addLibrary('wasmoon', LuaFactory, LuaMultiReturn)
    .addLibrary('runtime', {uptime: false})
    .addLibrary('keyboard')
    .addLibrary('resize')
    .setEngine('https://cdn.jsdelivr.net/npm/@gamely/gly-engine@latest/dist/main.lua')
    .setGame('game.lua')
    .build()
```

## Love2D

support wasmoon and fengari!

 * <https://cdn.jsdelivr.net/npm/@gamely/love-engine>

```js
const keymap = [
    ['KeyZ', 'a'],
    ['KeyX', 'b'],
    ['KeyC', 'c'],
    ['KeyV', 'd'],
    ['Enter', 'a'],
    ['ArrowUp', 'up'],
    ['ArrowDown', 'down'],
    ['ArrowLeft', 'left'],
    ['ArrowRight', 'right'],
    ['ShiftLeft', 'menu'],
];

const gly = await CoreNativeHtml5()
    .setElementRoot('main')
    .setElementCanvas('#gameCanvas')
    .addLibrary('fengari', fengari)
    .addLibrary('runtime', {unfocus_pause: true})
    .addLibrary('keyboard', keymap)
    .addLibrary('resize')
    .setEngine('https://cdn.jsdelivr.net/npm/@gamely/love-engine@latest/dist/main.lua')
    .setGame('main.lua')
    .build()
```

## Engine writen in lua

```js
const gly = await CoreNativeHtml5()
    .setElementRoot('main')
    .setElementCanvas('#gameCanvas')
    .addLibrary('wasmoon', window.LuaFactory, window.LuaMultiReturn)
    .addLibrary('fengari', window.fengari)
    .addLibrary('fengari-jsonrxi', 'https://cdn.jsdelivr.net/gh/rxi/json.lua/json.lua')
    .addLibrary('fengari-or-wasmoon-check')
    .addLibrary('player-videojs', window.videojs)
    .addLibrary('runtime')
    .addLibrary('keyboard')
    .addLibrary('resize')
    .setEngine('engine.lua')
    .setGame('game.lua')
    .build()
```

## Baremetal javascript

```js
const gly = await CoreNativeHtml5()
    .setElementCanvas('#gameCanvas')
    .build()

gly.engine.on('draw', () => {
    gly.backend.native_draw_color(0xFFFFFFFFF)
    gly.backend.native_draw_rect(0, 50, 50, 50, 50)
})

function tick() {
    gly.frontend.native_callback_loop()
    gly.frontend.native_callback_draw()
    window.requestAnimationFrame(tick)
}

gly.frontend.native_callback_init()
tick();
```

## Custom engine javascript

```js
function awesome_game(loop, draw, keys) {
    let color = 0x00FFFFFF

    loop.callback(() => {

    })
    draw.callback(() => {
        draw.color(color)
        draw.rect(0, 10, 20, 30, 40)
    })
    keys.callback((key, press) => {
        if (key == 'a' && press) {
            color = 0xFF0000FF
        }
    })
}
```

```js
function awesome_engine(game) {
    CoreNativeHtml5().setElementCanvas('#game').addLibrary('keyboard').addLibrary('runtime').build().then((gly) => {
        const loop = {
            callback: (f) => gly.on('loop', f)
        }
        const draw = {
            color: gly.backend.native_draw_color,
            rect: gly.backend.native_draw_rect,
            callback: (f) => gly.on('draw', f)
        }
        const keys = {
            callback: (f) => gly.on('keyboard', f)
        }
    
        game(loop, draw, keys)
    })
}
```

```js
awesome_engine(awesome_game)
```
