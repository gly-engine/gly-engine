import { lauxlib, lualib } from "fengari";
import { to_luastring } from "fengari/src/fengaricore";

import * as fs from "fs";
import * as path from "path";
import * as glue from "./glue.ts";
import { fileURLToPath } from "url";

function main() {
  const L = lauxlib.luaL_newstate();
  const main = path.resolve(fileURLToPath(import.meta.url), '..', '..', '..', 'source', 'cli', 'main.lua');
  const script = to_luastring(glue.bootstrap() + fs.readFileSync(main, 'utf8'));
  lualib.luaL_openlibs(L);
  glue.overridePrint(L);
  glue.addNpmToLuaPath(L);
  glue.setLuaArgs(L, process.argv.slice(2));
  glue.registerJsRequire(L);
  glue.createBufferTable(L);
  glue.doScript(L, script as unknown as string);
}

main();
