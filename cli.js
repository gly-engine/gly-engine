#!/usr/bin/env node
const { execFileSync } = require('child_process');
const { existsSync, renameSync } = require('fs');
const { resolve } = require('path');

const GLY_PATH = resolve('npm', 'gly-cli');
const GLY_CLI = resolve(GLY_PATH, 'src', 'index.ts');
const GLY_VENDOR = resolve(GLY_PATH, 'node_modules');
const ROOT_VENDOR = resolve('node_modules');

try {
  if (!existsSync(GLY_VENDOR) && !existsSync(ROOT_VENDOR)) {
    execFileSync('npm', ['install', '--no-package-lock'], {
      shell: true,
      cwd: GLY_PATH,
      env: process.env,
      stdio: 'inherit'
    });
    renameSync(GLY_VENDOR, ROOT_VENDOR);
  }
  execFileSync('npx', ['--prefix', GLY_PATH, 'bun', GLY_CLI, ...process.argv.slice(2)], { 
    shell: true,
    env: process.env,
    stdio: 'inherit'
  });
} catch (e) {
  process.exit(1);
}
