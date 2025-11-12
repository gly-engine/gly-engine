local agent = require('source/agent')
local version = require('source/version')
local env = require('source/shared/string/parse/env')
local base64 = require('source/shared/string/encode/base64')
local ltable = require('source/shared/string/encode/table')
local zlib = require('source/third_party/zerkman_zlib')
local json = require('source/third_party/rxi_json')
local javascript = require('source/shared/string/encode/javascript')
local lustache = require('source/third_party/olivinelabs_lustache')
local ftcsv = require('source/third_party/fouriertransformer_ftcsv')
local util_decorator = require('source/shared/functional/decorator')
local cli_buildder = require('source/cli/build/builder')
local eval_code = require('source/shared/string/eval/code')
local build_ncl = require('source/shared/var/build/ncl')
local build_html = require('source/shared/var/build/html')
local build_screen = require('source/shared/var/build/screen')
local runtime_bin = require('source/shared/var/runtime/bin')
local runtime_flag = require('source/shared/var/runtime/flag')
local deep_merge = require('source/shared/table/deep_merge')

local csv = {
    decode = function(c)
        return ftcsv.parse(c, {loadFromString=true})
    end,
    encode = function(c)
        local ok, res = pcall(ftcsv.encode, c)
        if ok then return res end
        ok, res = pcall(ftcsv.encode, {c})
        if ok then return res end
        return nil
    end
}

local function filter(array, fn)
    local result, index = {}, 1
    while index <= #array do
        if fn(array[index], index) then
            result[#result + 1] = array[index] 
        end
        index = index + 1
    end
    return result
end

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
        end,
        safe_lua = function()
            return ltable.safe_encode(tbl)
        end,
        lua = function()
            return ltable.encode(tbl)
        end,
        csv = function()
            return csv.encode(tbl) or error('is not a table!', 0)
        end,
        ['js-var'] = function()
            return javascript.var(tbl)
        end,
        ['js-const'] = function()
            return javascript.const(tbl)
        end,
        ['js-esm'] = function()
            return javascript.esm(tbl)
        end,
        ['js-esm-default'] = function()
            return javascript.esm_default(tbl)
        end,
        ['js-common'] = function()
            return javascript.cjs_default(tbl)
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

local function try_lua(content)
    local ok, data = pcall(function()
        local lua_code = cli_buildder.optmizer(content, 'gamelua', {})
        local ok_eval, lua_evaluated = eval_code.script(table.concat(lua_code, '\n'))
        return (ok_eval and lua_evaluated)
    end)
    return (ok and data and next(data) ~= nil) and data
end

local function try_decode(content, parser)
    local ok, data = pcall(function()
        return parser.decode(content)
    end)
    return (ok and data and next(data) ~= nil) and data
end

local function try_tic80(content)
    local ok, data = pcall(function()
        local m = {}
        local done = false
        for l in content:gmatch("[^\r\n]+") do
            if done then return next(m) and {meta = m} or {} end
            local k, v = l:match("%-%-%s*(%w+)%s*:%s*(.*)")
            if k and (k == 'title' or k == 'author' or k == 'desc' or k == 'version' or k == 'ver') then
                m[k] = v
            elseif next(m) and not l:match("%-%-") then
                done = true
            end
        end
        return next(m) and {meta = m}
    end)
    return ok and data and next(data or {}) ~= nil and data
end

local function try_love(love_content)
    local ok, data = pcall(function ()
        _G.love = {}
        local love_start = love_content:find("PK\003\004", 1, true)
        local love_data = love_content:sub(love_start)
        local love_conf = zlib.unzip(love_data, 'conf.lua')
        local love_meta = {window={},audio={},modules={},screen={}}
        eval_code.script(love_conf)
        if _G.love.conf then
            _G.love.conf(love_meta)
        end
        _G.love = nil
        return love_meta
    end)
    return ok and data
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

local function metadata(infiles, args, optional)
    if type(infiles) ~= 'table' then
        infiles = {infiles}
    end

    local merged_game = nil
    for _, infile in ipairs(infiles) do
        if type(infile) == 'string' then
            local f = io.open(infile, 'rb')
            if f then
                infile = f:read('*a')
                f:close()
            end
        end

        local game_part = try_lua(infile)
            or try_decode(infile, json)
            or try_decode(infile, env)
            or try_decode(infile, csv)
            or try_tic80(infile)
            or try_love(infile)
        
        merged_game = deep_merge.table(merged_game, game_part)
    end

    local game = normalize_table(merged_game) or (optional and {})

    if not game then 
        return nil
    end
    
    local meta = normalized_meta(game)
    local envs = env.normalize(game)

    local data = {
        env = envs,
        self = game,
        meta = meta,
        engine = {
            agent = agent,
            version = version,
        },
        assets = {
            png = filter(game.assets or {}, function(str) return str:find('%.png$') end),
            list = game.assets or {},
            fonts = game.fonts or {}
        },
        dump = {
            meta = dumper(meta),
            raw = dumper(game),
            env = dumper(envs),
        },
        fn = {
            colon = fn_colon,
            case = fn_case,
            b64 = fn_b64
        }
    }

    data.dump.meta.tic80 = function()
        return '-'..'- title:  '..meta.title..'\n-'..'- author: '..meta.author
            ..'\n-'..'- desc:   '..meta.description..'\n-'..'- ver:    '..meta.version..'\n-'..'- script: lua'
    end

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
    metadata = metadata,
    lazy_metada = function(a, b, c) return function() return metadata(a, b, c) end end
}

return P
