/**
 * @version 0.2.4
 */

export type GlyNode = Record<string, unknown>;

export type GlyApp = GlyNode & {
  data: {
    width: number;
    height: number;
  } & Record<string, unknown>;
};

export type GlyStdJsx = (el: string | object, attributes?: object | null, ...childs: Array<object>) => GlyApp;

export type GlyHandlerArgs = (this: void, ...args: unknown[]) => unknown

export type GlyHandlerValueString = (this: void, value: string) => unknown

export type GlyHandlerStdData<T = GlyStd> = (this: void, std: T, data: GlyApp) => unknown

declare class GlyHttp {
  public json(): GlyHttp;
  public fast(): GlyHttp;
  public noforce(): GlyHttp;
  public param(key: string, value: string): GlyHttp;
  public header(key: string, value: string): GlyHttp;
  public body(content: string): GlyHttp;
  public body(content: object): GlyHttp;
  public success(handler: GlyHandlerStdData<GlyStdWithHttpResponse>): GlyHttp;
  public failed(handler: GlyHandlerStdData<GlyStdWithHttpResponse>): GlyHttp;
  public error(handler: GlyHandlerStdData<GlyStdWithHttpResponse>): GlyHttp;
  public done(handler: GlyHandlerStdData<GlyStdWithHttpResponse>): GlyHttp;
  public run(): void;
}

declare class GlyMedia {
  public src(url: string): GlyMedia;
  public play(): GlyMedia;
  public pause(): GlyMedia;
  public resume(): GlyMedia;
  public stop(): GlyMedia;
  public position(x: number, y: number, w: number, h: number): GlyMedia;
}

declare class GlyStorage {
  public as(key: string, cast?: GlyHandlerValueString): GlyStorage;
  public default(value: string): void;
  public callbacks(handler: GlyHandlerValueString): GlyStorage;
  public run(): void;
}

declare class GlyUi {
  public add(node: GlyNode): GlyUi;
  public add(node: GlyNode, size: number): GlyUi;
  public get_item(id: number): GlyApp;
  public get_items(): Array<GlyApp>;
  public add_items(nodes: GlyNode[]): GlyUi;
  public remove(app: GlyApp): GlyUi;
}

/** @noSelf **/
interface GlyStdApp {
  exit(): void;
  height: number;
  reset(): void;
  width: number;
}

interface GlyStdArray {
  each<T>(array: T[], func: (item: T, index: number, array: T[]) => void): void;
  every<T>(array: T[], func: (item: T, index: number, array: T[]) => boolean): boolean;
  filter<T>(array: T[], func: (item: T, index: number, array: T[]) => boolean): T[];
  first<T>(array: T[], func?: (item: T, index: number, array: T[]) => boolean): T | undefined;
  index<T>(array: T[], func: (item: T, index: number, array: T[]) => boolean, reverse?: boolean): number;
  map<T, U>(array: T[], func: (item: T, index: number, array: T[]) => U): U[];
  reducer<T, U>(array: T[], func: (acc: U, item: T, index: number, array: T[]) => U, value: U): U;
  some<T>(array: T[], func: (item: T, index: number, array: T[]) => boolean, reverse?: boolean): boolean;
  unique<T>(array: T[]): T[];
}

/** @noSelf **/
interface GlyStdBus {
  abort(): void;
  emit_next(key: string, ...args: unknown[]): void;
  emit(key: string, ...args: unknown[]): void;
  listen(key: string, handler: GlyHandlerArgs): void;
  trigger(key: string): void;
}

/** @noSelf **/
interface GlyStdColor {
  beige: number;
  black: number;
  blank: number;
  blue: number;
  brown: number;
  darkblue: number;
  darkbrown: number;
  darkgray: number;
  darkgreen: number;
  darkpurple: number;
  gold: number;
  gray: number;
  green: number;
  lightgray: number;
  lime: number;
  magenta: number;
  maroon: number;
  orange: number;
  pink: number;
  purple: number;
  red: number;
  skyblue: number;
  violet: number;
  white: number;
  yellow: number;
}

/** @noSelf **/
interface GlyStdDraw {
  clear(hex: number): void;
  color(hex: number): void;
  line(x1: number, y1: number, x2: number, y2: number): void;
  poly(mode: number, verts: Array<number>, x?: number, y?: number, scale?: number, angle?: number, ox?: number, oy?: number): void;
  rect(mode: number, x: number, y: number, w: number, h: number): void;
  rect2(mode: number, x: number, y: number, w: number, h: number, r: number): void;
}

/** @noSelf **/
interface GlyStdHash {
  djb2(digest: string): number;
  fingerprint(): number;
}

/** @noSelf **/
interface GlyStdHttp {
  delete(url: string): GlyHttp;
  get(url: string): GlyHttp;
  head(url: string): GlyHttp;
  patch(url: string): GlyHttp;
  post(url: string): GlyHttp;
  put(url: string): GlyHttp;
}

/** @noSelf **/
interface GlyStdHttpResponse {
  ok: boolean,
  status: number
  error?: string
  body: string | object
}

/** @noSelf **/
interface GlyStdI18n {
  back(): void;
  get_language(): string;
  get_text(old_text: string): string;
  next(): void;
  set_language(language: string): void;
}

/** @noSelf **/
interface GlyStdImage {
  mensure_height(src: string): number;
  mensure_width(src: string): number;
  mensure(src: string): LuaMultiReturn<[number, number]> | LuaMultiReturn<[undefined, undefined]>;
  draw(src: string, x?: number, y?: number): void;
  load(src: string): number;
  exists(src: string): boolean;
  unload(src: string): void;
  unload_all(): void;
}

/** @noSelf **/
interface GlyStdKey {
  axis: {
    a: 0 | 1;
    b: 0 | 1;
    c: 0 | 1;
    d: 0 | 1;
    down: 0 | 1;
    left: 0 | 1;
    menu: 0 | 1;
    right: 0 | 1;
    up: 0 | 1;
    x: -1 | 0 | 1;
    y: -1 | 0 | 1;
  };
  press: {
    a: boolean;
    any: boolean;
    b: boolean;
    c: boolean;
    d: boolean;
    down: boolean;
    left: boolean;
    menu: boolean;
    right: boolean;
    up: boolean;
  };
  media: undefined | {
    ch_up: string;
    ch_down: string;
    vol_up: string;
    vol_down: string;
  };
}

/** @noSelf **/
interface GlyStdLog {
  debug(...data: any[]): void;
  error(...data: any[]): void;
  fatal(...data: any[]): void;
  info(...data: any[]): void;
  trace(...data: any[]): void;
  level(level: 'none' | 'fatal' | 'error' | 'warn' | 'info' | 'debug' | 'trace'): void;
  warn(...data: any[]): void;
}

/** @noSelf **/
interface GlyStdMath {
  abs(n: number): number;
  clamp(n: number, min: number, max: number): number;
  clamp2(n: number, min: number, max: number): number;
  dir(n: number): -1 | 0 | 1;
  dis(n: number): number;
  dis2(n: number): number;
  dis3(n: number): number;
  lerp(start: number, end: number, alpha: number): number;
  map(n: number, in_min: number, in_max: number, out_min: number, out_max: number): number;
  max(n: number[]): number;
  max(n1: number, n2: number, ...nx: number[]): number;
  min(n: number[]): number;
  min(n1: number, n2: number, ...nx: number[]): number;
}

/** @noSelf **/
interface GlyStdMathLibC {
  acos(x: number): number;
  asin(x: number): number;
  atan(x: number): number;
  atan2(y: number, x: number): number;
  ceil(x: number): number;
  cos(x: number): number;
  cosh(x: number): number;
  deg(x: number): number;
  exp(x: number): number;
  floor(x: number): number;
  fmod(x: number, y: number): number;
  frexp(x: number): [number, number];
  huge: number;
  ldexp(mantissa: number, exponent: number): number;
  log(x: number): number;
  log10(x: number): number;
  modf(x: number): [number, number];
  pi: number;
  pow(base: number, exponent: number): number;
  rad(x: number): number;
  sin(x: number): number;
  sinh(x: number): number;
  sqrt(x: number): number;
  tan(x: number): number;
  tanh(x: number): number;
}

/** @noSelf **/
interface GlyStdMedia {
  video(channel?: number): GlyMedia;
}

/** @noSelf **/
interface GlyStdMemory {
  cache(key: string, load: () => unknown, unload?: (value: unknown) => void): unknown;
  cache_get(key: string): unknown;
  cache_set(key: string, load: () => unknown, unload?: (value: unknown) => void): void;
  gc_clear_all(): void;
  unset(key: string): void;
}

/** @noSelf **/
interface GlyStdNode {
  emit(application: GlyApp, key: string, ...args: unknown[]): void;
  kill(application: GlyApp): void;
  load(application: GlyNode): GlyNode;
  pause(application: GlyApp): void;
  pause(application: GlyApp, key: string): void;
  resume(application: GlyApp): void;
  resume(application: GlyApp, key: string): void;
  spawn(application: GlyNode): GlyApp;
}

/** @noSelf **/
interface GlyStdStorage {
  get(key: string): GlyStorage;
  set(key: string, value: unknown): GlyStorage;
}

/** @noSelf **/
interface GlyStdText {
  font_default(size: number): void;
  font_name(face: string): void;
  font_previous(): void;
  font_size(size: number): void;
  is_tui(): boolean;
  mensure_height(src: string): number;
  mensure_width(src: string): number;
  mensure(text: string | number): LuaMultiReturn<[number, number]> | LuaMultiReturn<[undefined, undefined]>;
  print(x: number, y: number, text: string | number): void;
  print_ex(x: number, y: number, text: string | number, align_x?: -1 | 0 | 1, align_y?: -1 | 0 | 1): [number, number];
  put(x: number, y: number, text: string | number, size?: number): void;
}

/** @noSelf **/
interface GlyStdUi {
  grid(classlist: string): GlyUi;
  style(classlist: string): GlyUi;
  style(classlist: string, stylesheet: object): GlyUi;
}

/** @noSelf **/
export interface GlyStdNano {
  color: GlyStdColor;
  delta: number;
  draw: GlyStdDraw;
  image: GlyStdImage;
  key: GlyStdKey;
  milis: number;
  text: GlyStdText;
}

/** @noSelf **/
export interface GlyStdMicro extends GlyStdNano {
  app: GlyStdApp;
  array: GlyStdArray;
  math: GlyStdMath & GlyStdMathLibC;
  mem: GlyStdMemory;
}

/** @noSelf **/
export interface GlyStdLite extends GlyStdMicro {
  getenv(key: string): string;
  hash: GlyStdHash;
  http: GlyStdHttp;
  i18n: GlyStdI18n;
  log: GlyStdLog;
  media: GlyStdMedia;
  storage: GlyStdStorage;
}

/** @noSelf **/
export interface GlyStdWithHttpResponse extends GlyStd {
  http: GlyStdHttp & GlyStdHttpResponse
}

/** @noSelf **/
export interface GlyStd extends GlyStdLite {
  setenv(key: string, value: string): string;
  bus: GlyStdBus;
  h: GlyStdJsx;
  node: GlyStdNode;
  ui: GlyStdUi;
}