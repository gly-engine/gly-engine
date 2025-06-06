local template_prefix = '-'..'-GLYSTART '
local template = 'return {meta={title=\'Gly\',author=\'Gly\',version=\'0.0.0\'},callbacks={draw=function(s) s.draw.rect(0,8,8,8,8) end}}'

local function put(dest, size)
    local text_size = tostring(size)
    local template_size = #(template_prefix..template..text_size) + 2
    local padding_size = size - template_size

    if padding_size < 0 then
        return false, 'minimal size: '..template_size..' bytes.'
    end

    local padding = string.rep('\n', padding_size)
    local dest_file, dest_error = io.open(dest, 'wb')
    
    if not dest_file then
        return false, dest_error
    end

    dest_file:write(template_prefix..text_size..'\n'..template..padding..'\n')
    dest_file:close()
    
    return true
end

local function replace(src_in, game_in, out_dest)
    local src_file, src_err = io.open(src_in, 'rb')
    local game_file, game_err = io.open(game_in, 'rb')

    if not src_file or not game_file then
        return false, src_err or game_err
    end

    local src_content = src_file:read('*a')
    local game_content = game_file:read('*a')

    src_file:close()
    game_file:close()

    local start = src_content:find(template_prefix)
    local size = start and src_content:sub(start):match('^'..template_prefix..'(%d+)')

    if not start or not size then
        return false, 'template not found!'
    end

    local final = start + tonumber(size)
    local template_size = final - start

    if template_size < #game_content then
        return false, 'maximum size: '..template_size..' bytes.'
    end

    local padding_size = template_size - #game_content
    local padding = string.rep('\n', padding_size)
    
    local out_file, out_err = io.open(out_dest, 'wb')

    if not out_file then
        return false, out_err
    end

    out_file:write(src_content:sub(1, start - 1)..game_content..padding..src_content:sub(final))
    out_file:close()

    return true
end

local P = {
    put=put,
    replace=replace
}

return P
