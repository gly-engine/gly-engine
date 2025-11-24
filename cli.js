#!/usr/bin/env node
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';
import { resolve } from 'path';

const GLY_CLI = resolve(fileURLToPath(import.meta.url), '..', 'npm', 'gly-cli', 'index.ts');
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
