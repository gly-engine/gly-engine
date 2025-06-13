local agent = require('source/agent')
local version = require('source/version')
local env = require('source/shared/string/parse/env')
local base64 = require('source/shared/string/encode/base64')
local json = require('source/third_party/rxi_json')
local lustache = require('source/third_party/olivinelabs_lustache')
local util_decorator = require('source/shared/functional/decorator')
local cli_buildder = require('source/cli/build/builder')
local eval_code = require('source/shared/string/eval/code')
local build_ncl = require('source/shared/var/build/ncl')
local build_html = require('source/shared/var/build/html')
local build_screen = require('source/shared/var/build/screen')
local runtime_bin = require('source/shared/var/runtime/bin')
local runtime_flag = require('source/shared/var/runtime/flag')

local fn_colon = {
    from = function(self)
        return self:match('^(.-):')
    end,
    to = function(self)
        return self:match('^.-:(.+)$')
    end
}

local fn_case = {
    msdos = function(text, render)
        return render(text):upper():gsub('[^%a%d]', '')
    end,
    alpha = function(text, render)
        return render(text):gsub('[^%a%d]', ' '):gsub('[^%w]', ' ') :gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    end,
    upper = function(text, render)
        return render(text):upper()
    end,
    lower = function(text, render)
        return render(text):lower()
    end
}

local fn_b64 = {
    atob = function(text, render)
        return base64.encode(render(text))
    end, 
    btoa = function(text, render)
        return base64.decode(render(text))
    end
}

local function dumper(tbl)
    return {
        dotenv = function()
            return env.encode(tbl, true)
        end,
        json = function()
            return json.encode(tbl)
        end
    }
end

local function normalize_table(t)
  if type(t) ~= 'table' then return t end
  local r, count = {}, 0
  for k, v in pairs(t) do
    if type(v) ~= 'function' then
      local val = normalize_table(v)
      if type(val) ~= 'table' or next(val) ~= nil then
        r[k] = val
        count = count + 1
      end
    end
  end
  return count > 0 and r or nil
end

local function normalized_meta(app)
    local meta = app.meta or app.Game or {}
    local scan = function(...)
        for _, key in ipairs({...}) do
            local value =  meta[key] or meta[key:upper()] or app[key] or app[key:upper()]
            if value and #value > 0 then return value end
        end
        return ''
    end
    local version = function(s)
        local t = {}
        for part in s:gmatch("%d+") do t[#t+1] = part end
        return string.format("%d.%d.%d", tonumber(t[1]) or 0, tonumber(t[2]) or 0, tonumber(t[3]) or 0)
    end
    return {
        title = scan('title', 'name'),
        author = scan('author', 'vendor'),
        version = version(scan('version', 'ver', 'tag')),
        description = scan('description', 'desc', 'brief')
    }
end

local function try_table(infile)
    if type(infile) == 'table' then
        return infile
    end
    return nil
end

local function try_lua(infile)
    local ok, lua = pcall(dofile, infile)
    local ok2, lua2 = pcall(function()
        local lua_code = cli_buildder.optmizer(io.open(infile, 'r'):read('*a'), 'gamelua', {})
        local ok, lua_evaluated = eval_code.script(table.concat(lua_code, '\n'))
        return (ok and lua_evaluated)
    end)
    local data = (ok and lua) or (ok2 and lua2) or {}
    return type(data) == 'table' and next(data) ~= nil and data
end

local function try_decode(infile, parser)
    local ok, data = pcall(function()
        return parser.decode(io.open(infile, 'r'):read('*a'))
    end)
    return ok and next(data) ~= nil and data
end

local function try_tic80(infile, parser)
    local ok, data = pcall(function()
        local h, m = io.open(infile, "rb"), {}
        if not h then return end
        local done = false
        for l in h:lines() do
            if done then return next(m) and {meta = m} or {} end
            local k, v = l:match("%-%-%s*(%w+)%s*:%s*(.*)")
            if k and (k == 'title' or k == 'author' or k == 'desc' or k == 'version') then
                m[k] = v
            elseif next(m) and not l:match("%-%-") then
                done = true
            end
        end
        h:close()
        return next(m) and {meta = m}
    end)
    return ok and next(data or {}) ~= nil and data
end

local function vars(args)
    return {
        build = {
            core = {[(args.core or 'meta'):gsub('html5_', '')] = true},
            ncl = build_ncl,
            html5 = util_decorator.prefix1_t(args, build_html),
            screen = util_decorator.prefix1_t(args, build_screen)
        },
        run = {
            bin = util_decorator.prefix1_t(args, runtime_bin),
            flag = util_decorator.prefix1_t(args, runtime_flag),
        }
    }
end

local function metadata(infile, args, optional)
    local game = normalize_table(try_table(infile)
        or try_lua(infile)
        or try_decode(infile, json)
        or try_decode(infile, env)
        or try_tic80(infile)
    ) or (optional and {})

    if not game then 
        return nil
    end
    
    local meta = normalized_meta(game)
    local envs = env.normalize(game)

    local data = {
        app = game,
        env = envs,
        meta = meta,
        engine = {
            agent = agent,
            version = version,
        },
        assets = {
            list = game.assets or {},
            fonts = game.fonts or {}
        },
        dump = {
            meta = dumper(meta),
            raw = dumper(game),
            env = dumper(envs)
        },
        fn = {
            colon = fn_colon,
            case = fn_case,
            b64 = fn_b64
        }
    }

    if game.args and not args then
        args = game.args
    end

    if args then
        data.args = args
        data.var = vars(args)
    end

    return data
end

local function render(infile, content, args, optional)
    local data = metadata(infile, args, optional)
    return data and lustache:render(content, data)
end

local P = {
    vars = vars,
    render = render,
    metadata = metadata
}

return P
