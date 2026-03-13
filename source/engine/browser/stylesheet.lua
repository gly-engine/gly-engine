--! @file stylesheet.lua
--! @brief CSS stylesheet engine. Owns: stylesheet_dict, stylesheet_func (in engine.dom).
--! @details
--! INVARIANT: stylesheet_func[name] is always a valid transform function after stylesheet() call.
--! INVARIANT: stylesheet_dict[name] holds the parsed CSS values for name.
--! Closure key = options keys sorted alphabetically, concatenated as "key=value..." string.
--! parse_unit resolves px/%/vw/vh at parse time; resolve() handles pct at layout time.

--! @brief Dependency injection for mark_dirty (avoids circular require with dom.lua).
local _mark_dirty

local function init(mark_dirty_fn)
    _mark_dirty = mark_dirty_fn
end

--! @brief Parse a CSS value into a {value, unit} descriptor.
--! @param value number|string  e.g. 100, "100px", "50%", "10vw", "10vh"
--! @param screen_w number  viewport width (for vw)
--! @param screen_h number  viewport height (for vh)
--! @return table {value: number, unit: 'px'|'pct'}
local function parse_unit(value, screen_w, screen_h)
    if type(value) == 'number' then
        return { value = value, unit = 'px' }
    end
    local num, unit = value:match('^([%d%.%-]+)(%%?p?x?v?w?h?)$')
    num = tonumber(num)
    if unit == '%' then
        return { value = num / 100, unit = 'pct' }
    elseif unit == 'vw' then
        return { value = (num / 100) * (screen_w or 1280), unit = 'px' }
    elseif unit == 'vh' then
        return { value = (num / 100) * (screen_h or 720), unit = 'px' }
    end
    -- 'px' or bare number string
    return { value = num or 0, unit = 'px' }
end

--! @brief Resolve a parsed unit value to pixels given a parent dimension.
--! @param parsed table  from parse_unit()
--! @param parent_size number
--! @return number
local function resolve(parsed, parent_size)
    if parsed.unit == 'pct' then
        return parsed.value * parent_size
    end
    return parsed.value
end

--! @brief Build or retrieve a CSS transform closure for a named stylesheet class.
--! @details When options is provided, (re)creates the closure keyed by sorted options.
--!   When options is nil, returns existing closure (or nil if not registered).
--! @param self engine.dom
--! @param name string  stylesheet class name (e.g. 'card', 'card:focus')
--! @param options table|nil  {left,right,top,bottom,margin,width,height} — CSSUnit values
--! @return function(x,y,w,h) → x,y,w,h
local function stylesheet(self, name, options)
    local css = self.stylesheet_dict[name] or {}
    local exe = self.stylesheet_func[name]

    if options then
        -- build closure key from sorted option keys
        local keys = {}
        for k in pairs(options) do
            if k ~= 'class' and k ~= 'children' then
                keys[#keys + 1] = k
            end
        end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do
            parts[#parts + 1] = k .. '=' .. tostring(options[k])
        end
        local closure_key = table.concat(parts)

        -- if same key already registered, return existing closure
        if self.stylesheet_key and self.stylesheet_key[name] == closure_key and exe then
            return exe
        end

        -- parse options into css table
        css.left   = options.left   or options.margin or nil
        css.right  = options.right  or options.margin or nil
        css.top    = options.top    or options.margin or nil
        css.bottom = options.bottom or options.margin or nil
        css.height = options.height or nil
        css.width  = options.width  or nil

        -- store closure key
        if not self.stylesheet_key then self.stylesheet_key = {} end
        self.stylesheet_key[name] = closure_key

        -- force new closure creation
        exe = nil
    end

    if not exe then
        -- parse at closure creation time; % resolved at layout time
        local sw = self.width  or 1280
        local sh = self.height or 720

        local p_left   = css.left   and parse_unit(css.left,   sw, sh) or nil
        local p_right  = css.right  and parse_unit(css.right,  sw, sh) or nil
        local p_top    = css.top    and parse_unit(css.top,    sw, sh) or nil
        local p_bottom = css.bottom and parse_unit(css.bottom, sw, sh) or nil
        local p_width  = css.width  and parse_unit(css.width,  sw, sh) or nil
        local p_height = css.height and parse_unit(css.height, sw, sh) or nil

        exe = function(x, y, width, height)
            local has_left   = p_left   ~= nil
            local has_right  = p_right  ~= nil
            local has_top    = p_top    ~= nil
            local has_bottom = p_bottom ~= nil

            local css_left   = has_left   and resolve(p_left,   width)  or 0
            local css_right  = has_right  and resolve(p_right,  width)  or 0
            local css_top    = has_top    and resolve(p_top,    height) or 0
            local css_bottom = has_bottom and resolve(p_bottom, height) or 0

            if p_width then
                local css_width = resolve(p_width, width)
                if (has_left and has_right) or (not has_left and not has_right) then
                    local free = width - css_left - css_right - css_width
                    x = x + css_left + free * (1/2)
                    width = css_width
                elseif not has_left and has_right then
                    x = x + width - css_right - css_width
                    width = css_width
                else
                    x = x + css_left
                    width = css_width
                end
            else
                if has_left then
                    x = x + css_left
                    width = width - css_left
                end
                if has_right then
                    width = width - css_right
                end
            end

            if p_height then
                local css_height = resolve(p_height, height)
                if (has_top and has_bottom) or (not has_top and not has_bottom) then
                    local free = height - css_top - css_bottom - css_height
                    y = y + css_top + free * (1/2)
                    height = css_height
                elseif not has_top and has_bottom then
                    y = y + height - css_bottom - css_height
                    height = css_height
                else
                    y = y + css_top
                    height = css_height
                end
            else
                if has_top then
                    y = y + css_top
                    height = height - css_top
                end
                if has_bottom then
                    height = height - css_bottom
                end
            end

            return x, y, width, height
        end
    end

    self.stylesheet_dict[name] = css
    self.stylesheet_func[name] = exe

    return exe
end

--! @brief Add a CSS function to a node's css list if not already present.
--! @param self engine.dom
--! @param func function  css transform function
--! @param node table
local function css_add(self, func, node)
    local styles = node.config.css
    local found = false

    for i = 1, #styles do
        if styles[i] == func then found = true; break end
    end

    if not found then
        styles[#styles + 1] = func
    end

    if _mark_dirty then _mark_dirty(self, node) end
end

--! @brief Remove a CSS function from a node's css list.
--! @param self engine.dom
--! @param func function  css transform function
--! @param node table
local function css_del(self, func, node)
    local styles = node.config.css
    local src, dst = 1, 1

    while src <= #styles do
        local item = styles[src]
        if item ~= func then
            styles[dst] = item
            dst = dst + 1
        end
        src = src + 1
    end

    while dst <= #styles do
        styles[dst] = nil
        dst = dst + 1
    end

    if _mark_dirty then _mark_dirty(self, node) end
end

--! @brief Create a scroll-offset CSS transform from a scroll_state table.
--! @param scroll_state table {offset_x: number, offset_y: number}
--! @return function(x,y,w,h) → x,y,w,h
local function css_scroll(scroll_state)
    return function(x, y, w, h)
        return x - (scroll_state.offset_x or 0), y - (scroll_state.offset_y or 0), w, h
    end
end

local P = {
    init       = init,
    parse_unit = parse_unit,
    resolve    = resolve,
    stylesheet = stylesheet,
    css_add    = css_add,
    css_del    = css_del,
    css_scroll = css_scroll,
}

return P
