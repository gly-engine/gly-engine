#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const { execFileSync } = require('child_process');

async function buildSelf() {
  let minify;
  try {
    minify = require('terser').minify;
  } catch (e) {
    console.error('gly-cli: terser not found, run: npm install');
    process.exit(1);
  }

  const root = __dirname;
  const dist = path.join(root, 'dist');
  const cli = path.join(root, 'npm', 'gly-cli', 'cli.js');
  const shebang = '#!/usr/bin/env node\n';

  const gly = (args, capture) => execFileSync(process.execPath, [cli, ...args], {
    cwd: root,
    encoding: 'utf8',
    stdio: capture ? ['inherit', 'pipe', 'ignore'] : ['inherit', 'inherit', 'ignore']
  });

  gly(['cli-build']);

  gly(['compile', 'dist/cli.lua', '--outfile', 'dist/cli.out']);
  const bytecode = fs.readFileSync(path.join(dist, 'cli.out'));
  const embedded = zlib.deflateRawSync(bytecode, { level: 9, memLevel: 9 }).toString('base64');

  gly(['bundler-js', 'npm/gly-cli/cli.js', '--outfile', 'dist/cli.js']);

  const bundlePath = path.join(dist, 'cli.js');
  const bundle = fs.readFileSync(bundlePath, 'utf8').replace('@bootstrap-cli', () => embedded);
  const minified = await minify(bundle, { format: { comments: false } });
  fs.writeFileSync(bundlePath, shebang + minified.code);
  fs.chmodSync(bundlePath, 0o755);

  const version = gly(['meta', 'source/cli/main.lua', '--format', 'version={{ meta.version }}'], true);
  fs.writeFileSync(path.join(dist, 'cli.version'), version);
  const pkg = gly(['meta', 'package.json', 'dist/cli.version', '--format', '{{& dump.raw.json}}'], true);
  fs.writeFileSync(path.join(dist, 'package.json'), pkg);

  gly(['fs-replace', 'README.md', './dist/README.md', '--format', 'lua cli.lua', '--replace', 'npx gly-cli']);

  for (const file of ['cli.out', 'cli.lua', 'cli.version']) {
    fs.rmSync(path.join(dist, file), { force: true });
  }
}

if (process.argv[2] === 'cli-build') {
  buildSelf();
} else {
  require('./npm/gly-cli/cli.js');
}
