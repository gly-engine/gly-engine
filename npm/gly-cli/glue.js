const fs = require('fs');
const path = require('path');
const child_process = require('child_process');

const root = path.resolve(__dirname, '..', '..');

function loadRuntime() {
  try {
    return require('fengari');
  } catch (e) {
    console.error('gly-cli: lua runtime not found!');
    console.error('install it with: npm install fengari');
    process.exit(1);
  }
}

const { lua, lauxlib, lualib, to_luastring, to_jsstring } = loadRuntime();

function createModuleTable(L, functions) {
  lua.lua_newtable(L);
  for (const [name, fn] of Object.entries(functions)) {
    lua.lua_pushstring(L, to_luastring(name));
    lua.lua_pushcfunction(L, fn);
    lua.lua_settable(L, -3);
  }
}

function createState() {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  return L;
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
  lua.lua_newtable(L);
  args.forEach((arg, i) => {
    lua.lua_pushinteger(L, i + 1);
    lua.lua_pushstring(L, to_luastring(arg));
    lua.lua_settable(L, -3);
  });
  lua.lua_setglobal(L, to_luastring("arg"));
}

function createBufferTable(L) {
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

function doScript(L, luaCode) {
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
  createState,
  bootstrap,
  addNpmToLuaPath,
  overridePrint,
  setLuaArgs,
  createBufferTable,
  registerJsRequire,
  doScript
};
