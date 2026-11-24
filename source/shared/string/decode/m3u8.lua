local function trim(str)
    return (str:gsub('^%s+', ''):gsub('%s+$', ''))
end

--! @par Attribute list
--! @details parse @c key=value or @c key="quoted, value" pairs.
--! keys are lowercased so @c BANDWIDTH and @c tvg-id share the same style.
--! when @c is_extinf is set, pairs are separated by spaces and the first
--! comma outside quotes ends the list (the rest is the title),
--! otherwise pairs are separated by commas (HLS attribute list).
local function attributes(str, pos, is_extinf)
    local attrs = {}
    local len = #str
    while pos <= len do
        local skip = is_extinf and '^%s+' or '^[%s,]+'
        local _, skip_end = str:find(skip, pos)
        if skip_end then pos = skip_end + 1 end
        if pos > len then break end
        if is_extinf and str:sub(pos, pos) == ',' then break end

        local key, value, stop = str:match('^([%w_%-]+)%s*=%s*"([^"]*)"()', pos)
        if not key then
            key, value, stop = str:match(is_extinf and '^([%w_%-]+)%s*=%s*([^%s,]*)()' or '^([%w_%-]+)%s*=%s*([^,]*)()', pos)
        end
        if not key then break end
        attrs[key:lower()] = trim(value)
        pos = stop
    end
    return attrs, pos
end

local function extinf(value)
    local item = {}
    local duration, pos = value:match('^%s*(-?[%d%.]+)()')
    item.duration = tonumber(duration)
    item.attrs, pos = attributes(value, pos or 1, true)
    local title = value:match('^,(.*)$', pos)
    if title and #trim(title) > 0 then
        item.title = trim(title)
    end
    if item.attrs['group-title'] then
        item.group = item.attrs['group-title']
    end
    return item
end

local function merge(dst, src)
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

--! @short decode m3u / m3u8 playlist (extended M3U, IPTV and HLS)
--! @return {title, header, tags, playlist}
--! @li @c title from @c #PLAYLIST
--! @li @c header attributes in @c #EXTM3U line (eg: @c url-tvg)
--! @li @c tags other @c #EXT tags, lowercased without @c ext-x- prefix
--! @li @c playlist list of @c {url, title, duration, group, attrs}
local function decode(content)
    content = content:gsub('^\239\187\191', '')
    local first = content:match('^%s*([^\r\n]*)')
    if not first or not first:match('^#EXTM3U') then
        error('is not a m3u8 playlist!', 0)
    end

    local result = {
        header = (attributes(first, 8, true)),
        tags = {},
        playlist = {}
    }

    local pending = nil
    local is_header = true
    for raw in content:gmatch('[^\r\n]+') do
        local line = trim(raw)
        if is_header then
            is_header = false
        elseif line:sub(1, 1) == '#' then
            local tag, value = line:match('^#([%w_%-]+):?(.*)$')
            local name = tag and tag:upper()
            if name == 'EXTINF' then
                local item = extinf(value)
                if pending then
                    merge(item.attrs, pending.attrs or {})
                    item.group = pending.group or item.group
                end
                pending = item
            elseif name == 'EXT-X-STREAM-INF' then
                pending = pending or {attrs = {}}
                pending.attrs = merge(pending.attrs or {}, (attributes(value, 1)))
            elseif name == 'EXTGRP' then
                pending = pending or {attrs = {}}
                pending.group = trim(value)
            elseif name == 'PLAYLIST' then
                result.title = trim(value)
            elseif name and name:match('^EXT') then
                local key = name:lower():gsub('^ext%-x%-', '')
                result.tags[key] = #value > 0 and trim(value) or true
            end
        elseif #line > 0 then
            local item = pending or {attrs = {}}
            item.url = line
            result.playlist[#result.playlist + 1] = item
            pending = nil
        end
    end

    return result
end

local P = {
    decode = decode
}

return P
