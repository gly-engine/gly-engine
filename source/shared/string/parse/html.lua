local entities = {
    amp = '&',
    lt = '<',
    gt = '>',
    quot = '"',
    apos = '\'',
    nbsp = ' '
}

local aliases = {
    title = true,
    description = true,
    author = true
}

local function insensitive(word)
    return (word:gsub('%a', function(char)
        return '['..char:lower()..char:upper()..']'
    end))
end

local function trim(str)
    return (str:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function unescape(str)
    return (str:gsub('&(#?%w+);', function(name)
        if entities[name] then
            return entities[name]
        end
        local hex = name:match('^#[xX](%x+)$')
        local dec = name:match('^#(%d+)$')
        local code = (hex and tonumber(hex, 16)) or (dec and tonumber(dec))
        if code and code < 128 and (code > 31 or code == 9 or code == 10 or code == 13) then
            return string.char(code)
        end
        return nil
    end))
end

local function sanitize(html)
    local clean = html:gsub('<!%-%-.-%-%->', '')
    clean = clean:gsub('<'..insensitive('script')..'[%s>].-</'..insensitive('script')..'%s*>', '')
    clean = clean:gsub('<'..insensitive('style')..'[%s>].-</'..insensitive('style')..'%s*>', '')
    return clean
end

local function attributes(raw)
    local attrs, pos = {}, 1
    while pos <= #raw do
        local init, stop, key = raw:find('([%w_:%-]+)%s*', pos)
        if not init then
            break
        end
        pos = stop + 1
        local value = ''
        if raw:sub(pos, pos) == '=' then
            local _, quote_stop, quote = raw:find('^=%s*(["\'])', pos)
            if quote then
                local value_init = quote_stop + 1
                local value_stop = raw:find(quote, value_init, true) or (#raw + 1)
                value = raw:sub(value_init, value_stop - 1)
                pos = value_stop + 1
            else
                local _, bare_stop, bare = raw:find('^=%s*([^%s]+)', pos)
                value = bare or ''
                pos = (bare_stop or #raw) + 1
            end
        end
        attrs[key:lower()] = unescape(value)
    end
    return attrs
end

local function tag_next(html, lower, name, pos)
    local init, stop = lower:find('<'..name..'[%s/>]', pos)
    if not init then
        return nil
    end
    local close = lower:find('>', stop) or #html
    return html:sub(stop, close - 1), close + 1
end

local function decode(content)
    if type(content) ~= 'string' then
        return {}
    end

    local html = sanitize(content)
    local lower = html:lower()
    local entries, pos = {}, 1

    while true do
        local raw, next_pos = tag_next(html, lower, 'meta', pos)
        if not raw then
            break
        end
        pos = next_pos
        local attrs = attributes(raw)
        local key = attrs.name or attrs.property or attrs.itemprop
        if key and #key > 0 and attrs.content then
            entries[#entries + 1] = {
                key = key:lower(),
                value = attrs.content,
                named = attrs.name ~= nil
            }
        end
    end

    local meta, from_name, index = {}, {}, 1
    while index <= #entries do
        local item = entries[index]
        if meta[item.key] == nil or (item.named and not from_name[item.key]) then
            meta[item.key] = item.value
            from_name[item.key] = item.named
        end
        index = index + 1
    end

    index = 1
    while index <= #entries do
        local item = entries[index]
        local alias = item.key:match('^og:(.+)$') or item.key:match('^twitter:(.+)$')
        if alias and aliases[alias] and meta[alias] == nil then
            meta[alias] = item.value
        end
        index = index + 1
    end

    local out = {}
    local title_raw, title_pos = tag_next(html, lower, 'title', 1)
    if title_raw then
        local text = trim(unescape(html:sub(title_pos):match('^(.-)<') or ''))
        if #text > 0 then
            out.title = text
        end
    end

    if next(meta) then
        out.meta = meta
    end

    return out
end

local P = {
    decode = decode,
    unescape = unescape,
    attributes = attributes
}

return P
