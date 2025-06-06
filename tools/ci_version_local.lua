local cli_file = io.open('source/version.lua')
local cli_text = cli_file and cli_file:read('*a')
local cli_version = cli_text and cli_text:match('(%d+%.%d+%.%d+)')

local doxygen_file = io.open('Doxyfile')
local doxygen_text = doxygen_file and doxygen_file:read('*a')
local doxygen_version = doxygen_text and doxygen_text:match('(%d+%.%d+%.%d+)')

print('version:   ', cli_version)
print('doxygen:', doxygen_version)

assert(cli_version == doxygen_version)
