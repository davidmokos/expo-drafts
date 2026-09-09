#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
const [file, expected] = process.argv.slice(2);
const resolved = JSON.parse(await readFile(file, 'utf8'));
if (!expected || resolved.runtimeVersion !== expected) {
  throw new Error('This source does not reproduce the published native runtime. Republish the preview with the same build environment.');
}
process.stdout.write(`Verified native runtime ${expected}.\n`);
