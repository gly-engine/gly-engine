<div align="center">
<h1>:mechanical_arm:<br>GLY Engine<br><sup><sub>powered by <a href="https://gamely.com.br" target="_blank">gamely.com.br</a></sub></sup></h1>
</div>

> A Lua-based cross-platform engine for building games and apps that run on smart TVs, browsers, old consoles, and can be embedded into other engines or native apps.

[<img align="right" width="48%" src="https://raw.githubusercontent.com/RodrigoDornelles/RodrigoDornelles/master/media/ginga-asteroids.gif">](https://github.com/gly-engine/gly-engine/blob/main/samples/asteroids/game.lua)

 * **Write in lua and typescript** <br/><sup>_(and also JSX using Gly Internal Dom)_</sup>
 * **Frictionless Development** <br/><sup>_(Online [IDE](https://playground.gamely.com.br) or very easy installation)_</sup>
 * **Progressive "Television" Apps** <br/><sup>_(Like PWAs, but for Brazilian TVs)_</sup>
 * **Many Testing Tools** <br/><sup>_(REPL, Unit Tests, [TAS](https://tasvideos.org/WelcomeToTASVideos#WhatIsATas) Tests)_</sup>
 * **Pure Functions**

### Browser :globe_with_meridians:

```sql
lua cli.lua build @asteroids
```

### Love 2D :heart_decoration: :desktop_computer:

```sql
lua cli.lua build @asteroids --core love --run
```

### Ginga :brazil: :tv:

```sql
lua cli.lua build @asteroids --core ginga --enterprise
```

## How to Install

#### Using Lua

```
wget http://get.gamely.com.br/cli.lua
```

#### Using Javascript

```
npm install @gamely/gly-cli
```

## Engine Platform Support

| Support| Target                    | Current Status 
| :----: | :------------------------ | :------------ |
| Tier 1 | HTML5, WebOS2020 or later | main platform for production
| Tier 2 | Love2D                    | main platform for development
| Tier 3 | Tizen 8                   | support
| Tier 4 | WebOS 6                   | support
| Tier 5 | Native Core Desktop       | support being reworked
| Tier 6 | Native Core Arduino       | support
| Tier 7 | Ginga                     | support
| Tier 8 | Console TUI (ASCII)       | support
| Tier 9 | Play Station 2            | coming soon
| Tier 10 | Nintendo Wii             | support, (broken wiipads)
| Tier 11 | Nintendo DS              | support, except images
| Tier 12 | Nintendo GBA             | support, except images
| Tier 13 | TIC-80 fantasy console   | support, except images
| Tier 14 | Play Station 1           | support, very limited
| Tier 15 | PICO-8 fantasy console   | support, very limited