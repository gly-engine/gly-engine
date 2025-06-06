local function dos()
    return (mock_separator or (_G.package and _G.package.config) or '/'):sub(1,1) ~= '/'
end

local function lsdir()
    if dos() then
        return 'dir /s /b '
    end
    return 'ls -1 '
end

local function rmdir()
    if dos() then
        return 'rmdir /s /q '
    end
    return 'rm -Rf '
end

local function mkdir()
    if dos() then
        return 'mkdir '
    end
    return 'mkdir -p '
end

local function move()
    if dos() then
        return 'move '
    end
    return 'mv '
end

local function del()
    if dos() then
        return 'del /q /s '
    end
    return 'rm -Rf '
end

local function silent()
    if dos() then
        return ' 2> nul > nul'
    end
    return ' 2> /dev/null > /dev/null'
end

local P = {
    silent=silent,
    lsdir=lsdir,
    rmdir=rmdir,
    mkdir=mkdir,
    move=move,
    del=del
}

return P
