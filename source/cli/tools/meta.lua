local agent = require('source/agent')
local version = require('source/version')
local json = require('source/third_party/rxi_json')
local ncl = require('source/shared/var/build/ncl')
local env_build = require('source/shared/var/build/build')
local lustache = require('source/third_party/olivinelabs_lustache')
local util_decorator = require('source/shared/functional/decorator')

local fn_colon = {
    from = function(self)
        return self:match('^(.+):.+$')
    end,
    to = function(self)
        return self:match('^.+:(.+)$')
    end
}

local fn_case = {
    msdos = function(text, render)
        return render(text):upper():gsub('[^%a%d]', '')
    end,
    upper = function()
        return render(text):upper()
    end,
    lower = function()
        return render(text):upper()
    end
}

function clone_no_fn(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do
    if type(v) ~= "function" then
      r[k] = type(v) == "table" and clone_no_fn(v) or v
    end
  end
  return r
end

function clean_copy(t)
  if type(t) ~= "table" then return t end
  local r, count = {}, 0
  for k, v in pairs(t) do
    local val = clean_copy(v)
    if type(val) ~= "table" or next(val) ~= nil then
      r[k] = val
      count = count + 1
    end
  end
  return count > 0 and r or nil
end

local function try_lua(infile)
    local ok, lua = pcall(dofile, infile)
    return ok and lua
end

local function try_json(infile)
    local ok, data = pcall(function()
        return json.decode(io.open(infile, 'r'):read('*a'))
    end)
    return ok and data
end

local function render(infile, content, args)
    local game = try_lua(infile) or try_json(infile) or {}

    game = clone_no_fn(game)
    game = clean_copy(game)

    local data = {
        engine = {
            agent = agent,
            version = version,
            ncl = env_ncl,
        },
        env = {

        },
        meta = game.meta or game,
        config = game.config or {},
        assets = {
            list = game.assets or {},
            fonts = game.fonts or {}
        },
        dump = {
            meta = {
                json = function()
                    return json.encode(game.meta)
                end
            },
            raw = {
                json = function()
                    return json.encode(game)
                end
            }
        },
        fn = {
            colon = fn_colon,
            case = fn_case
        }
    }

    if game.args and not args then
        args = game.args
    end

    if args then
        data.args = args
        data.env.build = util_decorator.prefix1_t(self.args, env_build)
        data.core = {[self.args.core] = true}
    end

    return lustache:render(content, data)
end

local P = {
    render = render
}

return P
