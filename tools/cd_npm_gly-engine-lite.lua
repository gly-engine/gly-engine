local cmd = function(c) assert(require('os').execute(c), c) end
local version = io.open('source/version.lua'):read('*a'):match('(%d+%.%d+%.%d+)')

cmd('rm -Rf ./dist')
cmd('./cli.sh build --core lite --bundler --outdir ./dist/dist/')
cmd('cp ./packages/npm_gly-engine/README.md ./dist/README.md')
cmd('mkdir -p ./dist/types')
cmd('echo "declare module \'@gamely/gly-engine-lite\' {\n const content: string;\n export default content;\n}" > dist/types/main.d.ts')
cmd('./cli.sh fs-replace ./packages/npm_gly-engine-lite/package.json ./dist/package.json --format "{{version}}" --replace '..version)
