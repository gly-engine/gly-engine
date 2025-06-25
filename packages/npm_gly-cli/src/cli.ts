import { lauxlib, lualib } from "fengari";

import cli from "../../../dist/cli.txt" assert { type: "text" };

import * as zlib from "zlib";
import * as glue from "./glue.ts";

function main() {
  const L = lauxlib.luaL_newstate();
  const script = zlib.inflateRawSync(Buffer.from(cli, 'base64')) as unknown as string
  lualib.luaL_openlibs(L);
  glue.overridePrint(L);
  glue.setLuaArgs(L, process.argv.slice(2));
  glue.registerJsRequire(L);
  glue.createBufferTable(L);
  glue.doScript(L, script);
}

main();
