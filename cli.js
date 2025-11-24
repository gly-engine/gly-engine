#!/usr/bin/env node
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';
import { existsSync } from 'fs';
import { resolve } from 'path';

const RUNTIME = ['bun'].map(cmd => resolve('node_modules', '.bin', cmd)).find(existsSync);
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
  if (!RUNTIME) {
    console.error("[gly-cli] missing bun in package.json")
    process.exit(1);
  }
  execFileSync(RUNTIME, [GLY_CLI, ...process.argv.slice(2)], { 
    shell: false,
    env: process.env,
    stdio: 'inherit'
  });
} catch (e) {
  process.exit(1);
}
