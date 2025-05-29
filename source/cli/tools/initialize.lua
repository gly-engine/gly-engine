local os = require('os')
local util_cmd = require('src/lib/util/cmd')

local ok = true

local function create_file(filepath, content)
    local file = io.open(filepath, "w")
    if file then
        file:write(content)
        file:close()
    else
        print("Error while creating file: " .. filepath)
        ok = false
    end
end

local function create_directory(path)
    local success = os.execute(util_cmd.mkdir()..path)
    if not success then
        print("Error while creating directory: " .. path)
        ok = false
    end
end

local function init_project(args)
    local project_name = args.project
    local project_template = args.template
    local project_gamefile = io.open(project_template, 'r')

    ok = true

    if not project_gamefile then
        return false, 'cannot open template: '..project_template
    end

    local game_lua_content = project_gamefile:read('*a')

    if project_name ~= '.' then
        create_directory(project_name)
    end

    create_file(project_name .. "/.gitignore", ".DS_Store\nThumbs.db\nvendor\ndist\ncli.lua")
    
    create_directory(project_name .. "/dist")
    create_directory(project_name .. "/vendor")
    
    create_file(project_name .. "/README.md", "# " .. project_name .. "\n\n * **use:** `lua cli.lua build src/game.lua`\n")
    
    create_directory(project_name .. "/src")
    
    create_file(project_name .. "/src/game.lua", game_lua_content)

    return ok, ok and "Project " .. project_name .. " created with success!"
end

return {
    init = init_project
}
