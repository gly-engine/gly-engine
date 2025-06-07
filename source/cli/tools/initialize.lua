local os = require('os')
local str_fs = require('source/shared/string/schema/fs')
local str_cmd = require('source/shared/string/schema/cmd')

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
    local success = os.execute(str_cmd.mkdir()..' '..path)
    if not success then
        print("Error while creating directory: " .. path)
        ok = false
    end
end

local function init_project(args)
    local project_dir = str_fs.path(args.outdir).get_fullfilepath()
    local project_name = args.project
    local project_template = args.template
    local project_gamefile = io.open(project_template, 'r')

    ok = true

    if not project_gamefile then
        return false, 'cannot open template: '..project_template
    end

    local game_lua_content = project_gamefile:read('*a')

    if #project_dir > 0 and project_dir ~= '.' then
        create_directory(project_dir)
    end

    create_directory(project_dir.."dist")
    create_directory(project_dir.."vendor")
    create_directory(project_dir.."src")
    
    create_file(project_dir.."README.md", "# " .. project_name .. "\n\n * **use:** `lua cli.lua build src/game.lua`\n")
    create_file(project_dir.."src/game.lua", game_lua_content)
    create_file(project_dir..".gitignore", ".DS_Store\nThumbs.db\nvendor\ndist\ncli.lua")

    return ok, ok and "Project " .. project_name .. " created with success!"
end

return {
    init = init_project
}
