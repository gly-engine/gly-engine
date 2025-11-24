#!/usr/bin/env node
const { execFileSync } = require('child_process');
const { existsSync } = require('fs');
const { fileURLToPath } = require('url');
const { resolve } = require('path');

const GLY_CLI = resolve(__dirname, 'npm', 'gly-cli', 'index.ts');
const ROOT_VENDOR = resolve('node_modules');

try {
  if (!existsSync(ROOT_VENDOR)) {
    execFileSync('npm', ['install', '--no-package-lock'], {
      shell: true,
      env: process.env,
      stdio: 'inherit'
    });
  }
  execFileSync('npx', ['bun', GLY_CLI, ...process.argv.slice(2)], { 
    shell: false,
    env: process.env,
    stdio: 'inherit'
  });
} catch (e) {
  process.exit(1);
}
