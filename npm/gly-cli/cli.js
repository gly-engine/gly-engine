#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const glue = require('./glue.js');

const cli = '@bootstrap-cli';

function getScript(L) {
  if (cli.startsWith('@')) {
    glue.addNpmToLuaPath(L);
    const mainLua = path.resolve(__dirname, '..', '..', 'source', 'cli', 'main.lua');
    return glue.bootstrap() + fs.readFileSync(mainLua, 'utf8');
  }
  return zlib.inflateRawSync(Buffer.from(cli, 'base64'));
}

function main() {
  const L = glue.createState();
  glue.overridePrint(L);
  glue.setLuaArgs(L, process.argv.slice(2));
  glue.registerJsRequire(L);
  glue.createBufferTable(L);
  glue.doScript(L, getScript(L));
}

main();
