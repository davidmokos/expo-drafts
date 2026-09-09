#!/usr/bin/env node
import { readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
const [file, output] = process.argv.slice(2);
const request = JSON.parse(await readFile(file, 'utf8'));
const result = spawnSync('eas', ['workflow:run', '.eas/workflows/build-draft.yml', '--non-interactive', '--json',
  '--input', `runtime_version=${request.runtimeVersion}`, '--input', `git_commit=${request.gitCommitHash}`,
  '--input', `request_id=${request.requestId}`], { encoding: 'utf8', maxBuffer: 5_000_000 });
if (result.error || result.status !== 0) {
  process.stderr.write(result.stderr || 'EAS dispatch failed.\n');
  process.exit(1);
}
const run = JSON.parse(result.stdout);
await writeFile(output, `${JSON.stringify(run, null, 2)}\n`);
process.stdout.write('Dispatched EAS native build workflow.\n');
