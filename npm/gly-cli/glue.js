const fs = require('fs');
const path = require('path');
const child_process = require('child_process');

const root = path.resolve(__dirname, '..', '..');
const ceifa = 'wasmoon';

let fengari = null;
let wasmoon = null;

function loadRuntime() {
  if (fengari || wasmoon) {
    return;
  }
  try {
    wasmoon = require(ceifa);
    return;
  } catch (e) {}
  try {
    fengari = require('fengari');
    return;
  } catch (e) {
    console.error('gly-cli: Lua runtime not found!');
    console.error('Install one of the supported runtimes:');
    console.error('  npm install wasmoon');
    console.error('  npm install fengari');
    process.exit(1);
  }
}

loadRuntime();

function is_fengari() {
  return fengari !== null;
}

const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari || {};

function createModuleTable(L, functions) {
  lua.lua_newtable(L);
  for (const [name, fn] of Object.entries(functions)) {
    lua.lua_pushstring(L, to_luastring(name));
    lua.lua_pushcfunction(L, fn);
    lua.lua_settable(L, -3);
  }
}

async function createState() {
  if (is_fengari()) {
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    return L;
  }
  const factory = new wasmoon.LuaFactory();
  return factory.createEngine({ injectObjects: true });
}

function bootstrap() {
  const mock = fs.readFileSync(`${root}/tests/mock/io.lua`, 'utf8');
  const bootstrap = fs.readFileSync(`${root}/source/cli/hazard/silvertap.lua`, 'utf8');
  const match = mock.match(/--! @bootstrap(.*?)--! @endbootstrap/s);
  if (!match) {
    throw new Error("Bootstrap section not found in mock file.");
  }
  const content = match[1] + bootstrap;
  return content;
}

function addNpmToLuaPath(L)
{
  if (!is_fengari()) {
    const rootLua = JSON.stringify(root);
    L.doStringSync(`
      table.insert(package.searchers, 2, function(name)
        local fs = jsRequire('fs')
        for _, file in ipairs({name .. '.lua', ${rootLua} .. '/' .. name .. '.lua'}) do
          if fs.existsSync(file) then
            return assert(load(fs.readFileSync(file, 'utf8'), '@' .. file))
          end
        end
        return '\\n\\tno gly module: ' .. name
      end)
    `);
    return;
  }

  lua.lua_getglobal(L, "package");
  lua.lua_getfield(L, -1, "path");

  let currentPath = to_jsstring(lua.lua_tostring(L, -1));
  currentPath += `;${root}/?.lua`;

  lua.lua_pop(L, 1);
  lua.lua_pushstring(L, to_luastring(currentPath));
  lua.lua_setfield(L, -2, "path");

  lua.lua_pop(L, 1);
}

function overridePrint(L) {
  if (!is_fengari()) {
    L.global.set('print', (...args) => console.log(args.join('\t')));
    return;
  }

  lua.lua_getglobal(L, to_luastring("_G"));
  lua.lua_pushjsfunction(L, function (L) {
    const n = lua.lua_gettop(L);
    const output = [];

    for (let i = 1; i <= n; i++) {
      output.push(to_jsstring(lua.lua_tolstring(L, i)));
    }

    console.log(output.join("\t"));
    return 0;
  });
  lua.lua_setfield(L, -2, to_luastring("print"));
  lua.lua_pop(L, 1);
}

function setLuaArgs(L, args) {
  if (!is_fengari()) {
    L.global.set('arg', args);
    return;
  }

  lua.lua_newtable(L);
  args.forEach((arg, i) => {
    lua.lua_pushinteger(L, i + 1);
    lua.lua_pushstring(L, to_luastring(arg));
    lua.lua_settable(L, -3);
  });
  lua.lua_setglobal(L, to_luastring("arg"));
}

function createBufferTable(L) {
  if (!is_fengari()) {
    L.global.set('Buffer', { from: (bytes) => Buffer.from(bytes) });
    return;
  }

  const bufferFns = {
    from: (L) => {
      if (!lua.lua_istable(L, 1)) {
        lua.lua_pushnil(L);
        return 1;
      }

      lua.lua_pushvalue(L, 1);
      return 1;
    }
  };

  createModuleTable(L, bufferFns);
  lua.lua_setglobal(L, to_luastring("Buffer"));
}

function getJsModules() {
  return {
    fs: {
      readFileSync: (L) => {
        const file = to_jsstring(lua.lua_tostring(L, 1));
        const filename = [file, `${root}/${file}`].find(fs.existsSync)
        const encoding = lua.lua_type(L, 2) === lua.LUA_TSTRING? to_jsstring(lua.lua_tostring(L, 2)): undefined;
        //! @todo lua if is dir is problematic interpolating with javascript
        if (fs.statSync(filename).isDirectory()) {
          lua.lua_pushstring(L, to_luastring('DIR'))
          return 1;
        }
        const data = fs.readFileSync(filename, encoding);
        lua.lua_pushstring(L, encoding? to_luastring(data): data);
        return 1;
      },
      existsSync: (L) => {
        const file = to_jsstring(lua.lua_tostring(L, 1));
        const filename = [file, `${root}/${file}`].find(fs.existsSync)
        lua.lua_pushboolean(L, filename !== undefined);
        return 1;
      },
      writeFileSync: (L) => {
        const filename = to_jsstring(lua.lua_tostring(L, 1));
        let content;

        if (lua.lua_type(L, 2) === lua.LUA_TSTRING) {
          content = to_jsstring(lua.lua_tostring(L, 2));
        } else if (lua.lua_type(L, 2) === lua.LUA_TTABLE) {
          const len = lua.lua_rawlen(L, 2);
          const arr = new Uint8Array(len);
          for (let i = 1; i <= len; i++) {
            lua.lua_rawgeti(L, 2, i);
            arr[i - 1] = lua.lua_tointeger(L, -1);
            lua.lua_pop(L, 1);
          }
          content = Buffer.from(arr);
        } else {
          return lauxlib.luaL_error(L, to_luastring("writeFileSync: segundo argumento deve ser string ou table"));
        }

        fs.writeFileSync(filename, content);
        return 0;
      },
      mkdirSync: (L) => {
        const dir = to_jsstring(lua.lua_tostring(L, 1));
        fs.mkdirSync(dir, { recursive: true });
        return 0;
      }
    },
    path: {
      dirname: (L) => {
        const filepath = to_jsstring(lua.lua_tostring(L, 1));
        lua.lua_pushstring(L, to_luastring(path.dirname(filepath)));
        return 1;
      }
    },
    child_process: {
      execSync: (L) => {
        const cmd = to_jsstring(lua.lua_tostring(L, 1));
        let output;

        try {
          output = child_process.execSync(cmd, { encoding: "utf8" });
        } catch (e) {
          output = e.message || "Erro";
        }

        lua.lua_pushstring(L, to_luastring(output));
        return 1;
      }
    }
  };
}

function registerJsRequire(L) {
  if (!is_fengari()) {
    L.global.set('jsRequire', (name) => require(name));
    return;
  }

  const modules = getJsModules();

  lua.lua_pushcfunction(L, (L) => {
    const modName = to_jsstring(lua.lua_tostring(L, 1));
    const mod = modules[modName];

    if (!mod) {
      lua.lua_pushnil(L);
      return 1;
    }

    createModuleTable(L, mod);
    return 1;
  });

  lua.lua_setglobal(L, to_luastring("jsRequire"));
}

async function doScript(L, luaCode) {
  if (!is_fengari()) {
    const code = typeof luaCode === 'string'? luaCode: Buffer.from(luaCode).toString('utf8');
    try {
      await L.doString(code);
    } catch (e) {
      console.error(e.message || e);
      process.exit(1);
    }
    return;
  }

  const code = typeof luaCode === 'string' ? to_luastring(luaCode) : luaCode;

  if (lauxlib.luaL_loadstring(L, code) !== lua.LUA_OK) {
    const message = lua.lua_tostring(L, -1);
    console.error(message instanceof Uint8Array ? to_jsstring(message) : message);
    lua.lua_close(L);
    process.exit(1);
  }

  if (lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
    const message = lua.lua_tostring(L, -1);
    console.error(message instanceof Uint8Array ? to_jsstring(message) : message);
    lua.lua_close(L);
    process.exit(1);
  }
}

module.exports = {
  is_fengari,
  createState,
  bootstrap,
  addNpmToLuaPath,
  overridePrint,
  setLuaArgs,
  createBufferTable,
  registerJsRequire,
  doScript
};
