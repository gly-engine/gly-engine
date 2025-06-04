local agent = require('source/agent')
local version = require('source/version')
local env = require('source/shared/string/dsl/env')
local base64 = require('source/shared/string/encode/base64')
local json = require('source/third_party/rxi_json')
local lustache = require('source/third_party/olivinelabs_lustache')
local util_decorator = require('source/shared/functional/decorator')
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
    local meta = app.meta or {}
    return {
        title = meta.title or meta.name or app.title or app.name or '',
        author = meta.author or meta.vendor or app.author or app.vendor or '',
        version = meta.version or app.version or app.tag or app.VERSION or '0.0.0',
        description = meta.description or app.description or ''
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
    return ok and lua
end

local function try_decode(infile, parser)
    local ok, data = pcall(function()
        return parser.decode(io.open(infile, 'r'):read('*a'))
    end)
    return ok and next(data) ~= nil and data
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

local function render(infile, content, args)
    local game = normalize_table(try_table(infile) or try_lua(infile) or try_decode(infile, json) or try_decode(infile, env))
    if not game then return nil end
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
        meta = meta,
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
        data.gly = vars(args)
    end

    return lustache:render(content, data)
end

local P = {
    vars = vars,
    render = render
}

return P
