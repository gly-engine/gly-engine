import { lauxlib, lualib } from "fengari";
import { to_luastring } from "fengari/src/fengaricore";

import * as fs from "fs";
import * as glue from "./glue.ts";

function main() {
  const L = lauxlib.luaL_newstate();
  const script = to_luastring(glue.bootstrap() + fs.readFileSync('source/cli/main.lua', 'utf8'))
  lualib.luaL_openlibs(L);
  glue.overridePrint(L);
  glue.setLuaArgs(L, process.argv.slice(2));
  glue.registerJsRequire(L);
  glue.createBufferTable(L);
  glue.doScript(L, script as unknown as string);
}

main();
