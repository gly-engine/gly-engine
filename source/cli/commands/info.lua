local version = require('src/version')

local help_message = "Available commands:\n"
  .."- init: Initializes a new game project. Requires a game path.\n"
  .."- build: Builds the game for distribution. Defaults to the 'ginga' core.\n"
  .."- run: Executes the specified game. Defaults to the 'love' core.\n"
  .."- meta: Displays metadata for the specified game.\n"
  .."- bundler: Builds the game using the specified bundler file.\n"
  .."- compiler: Compiles the specified file into an executable.\n"
  .."- tool-love-zip: Creates a zip file for the specified path.\n"
  .."- tool-love-exe: Creates an executable for the specified file.\n"
  .."- fs-replace: Replaces content in a file with specified format and replacement.\n"
  .."- fs-download: Downloads a file from the specified URL to the specified directory.\n"
  .."- cli-build: Bootstrap the CLI as a single file\n"
  .."- cli-test: Runs tests with optional coverage.\n"
  .."- cli-dump: Extract source code (when bootstrapped).\n"
  .."- version: Displays the current version of the tool.\n"
  .."- help: Displays this help message.\n"
  .."\n"
  .."Available cores:\n"
  .."- repl: Runs the REPL core.\n"
  .."- love: Runs the Love2D core.\n"
  .."- ginga: Runs the Ginga core.\n"
  .."- html5_webos: Builds for HTML5 on WebOS.\n"
  .."- html5_tizen: Builds for HTML5 on Tizen.\n"
  .."- html5: Runs the standard HTML5 core.\n"
  .."\n"
  .."Usage:\n"
  .."- To run a command, use: ./cli.sh <command> <game_path> [options]\n"
  .."- Example: ./cli.sh build ./samples/asteroids/game.lua " .. "-" .. "-core ginga\n"
  .."\n"
  .."Available options:\n"
  .."-" .. "-dist <path>: Specifies the distribution directory (default: './dist/').\n"
  .."-" .. "-core <core_name>: Specifies the core to use (default varies by command).\n"
  .."-" .. "-screen <resolution>: Specifies the screen resolution (default: '1280x720').\n"
  .."-" .. "-bundler: Indicates to use the bundler during the build process.\n"
  .."-" .. "-run: Indicates to run the game after building.\n"
  .."-" .. "-format <format>: Specifies the format for metadata display.\n"
  .."-" .. "-coverage: Enables coverage reporting for tests.\n"
  .."\n"
  .."Examples:\n"
  .."- To initialize a new game: ./cli.sh init ./my_game\n"
  .."- To build a game: ./cli.sh build ./samples/asteroids/game.lua " .. "-" .. "-core html5\n"
  .."- To run a game: ./cli.sh run ./samples/asteroids/game.lua "  .. "-" .. "-core repl\n"
  .."- To display metadata: ./cli.sh meta ./samples/asteroids/game.lua\n"

  local function help()
  return true, help_message
end

local function version_message()
  return true, version
end

local function meta()
  local description = 'not implemented!'
  return {
    meta={
      title='gly-cli',
      version=version,
      author='RodrigoDornelles',
      description=description
    }
  }
end

local function not_found(args)
  return false, 'command not found: '..args['command']
end

local function correct_usage(args)
  local index = 1
  local lua = args[0] or 'gly-cli'
  local runner = lua:find('.lua') and 'lua ' or ''
  local command = 'usage: '..runner..lua..' '..args.command

  while index <= #args.params do
    local param = args.params[index]
    command = command..' ['..param..']'
    index = index + 1
  end

  index = 1
  while index <= #args.option_get do
    local option = args.option_get[index]
    if not args.hidden[option] or args.extra then
      command = command..' -'..'-'..option..' ['..option..']'
    end
    index = index + 1
  end

  index = 1
  while index <= #args.option_has do
    local option = args.option_has[index]
    if not args.hidden[option] or args.extra then
      command = command..' --'..option
    end
    index = index + 1
  end

  return false, command
end

local P = {
  meta = meta,
  help = help,
  version = version_message,
  ['not-found'] = not_found,
  ['correct-usage'] = correct_usage
}

return P
