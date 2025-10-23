local function module_mock(src_in, mock_in, module_name)
    local src_file, src_err = io.open(src_in, 'r')
    local mock_file, mock_err = io.open(mock_in, 'r')

    if not src_file or not mock_file then
        return false, src_err or mock_err
    end

    local content = src_file:read('*a')
    src_file:close()

    local id_bundler = (content:match('local (b[%d%a]+)%s*=%s*%{%s*0[%s,0]*%}\n') or ''):sub(2)
    if #id_bundler == 0 then return true, 'is not a bundler!' end

    local id_module = content:match(('b{1}%[(%d+)%]%(\'{2}\'%)'):gsub('{1}', id_bundler):gsub('{2}', module_name))
    if not id_module then return false, 'module not found!' end

    local next_id_module = (tonumber(id_module) or -1) + 1
    local pattern_start = ('b{1}%[{2}%] = r{1}%({2}, function%(%)'):gsub('{1}', id_bundler):gsub('{2}', id_module)
    local pattern_end_1 = ('\nend%)\nb{1}%[{2}%] = r{1}%({2}, function%(%)'):gsub('{1}', id_bundler):gsub('{2}', next_id_module)
    local pattern_end_2 = ('\nend%)\nreturn m{1}%(%)'):gsub('{1}', id_bundler)
    local pos_end = content:find(pattern_end_1) or content:find(pattern_end_2)
    local pos_start = content:find(pattern_start)
    local header = pattern_start:gsub('%%', '')

    if not pos_start or not pos_end then return false, 'some error!' end

    local module_content = mock_file:read('*a')
    content = content:sub(1, pos_start - 1)..header..module_content..content:sub(pos_end, #content)
    mock_file:close()
    
    src_file = io.open(src_in, 'w')
    src_file:write(content)
    src_file:close()

    return true
end

local P = {
    mock = module_mock,
    builder_mock = function(a, b, c) return function() return module_mock(a, b, c) end end
}

return P
