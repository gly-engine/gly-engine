#!/usr/bin/env node
const { execFileSync } = require('child_process');
const { existsSync, renameSync } = require('fs');
const { join } = require('path');

const GLY_PATH = join('packages', 'npm_gly-cli');
const GLY_CLI = join(GLY_PATH, 'src', 'index.ts');
const GLY_VENDOR = join(GLY_PATH, 'node_modules');
const ROOT_VENDOR = join('node_modules');

try {
  if (!existsSync(GLY_VENDOR) && !existsSync(ROOT_VENDOR)) {
    execFileSync('npm', ['--prefix', GLY_PATH, 'install'], { stdio: 'inherit' });
    renameSync(GLY_VENDOR, ROOT_VENDOR);
  }
  execFileSync('npx', ['--prefix', GLY_PATH, 'bun', GLY_CLI, ...process.argv.slice(2)], { stdio: 'inherit' });
} catch (e) {
  process.exit(1);
}
