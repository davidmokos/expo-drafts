import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const request = {
  runtimeVersion: 'native-runtime',
  gitCommitHash: 'a'.repeat(40),
  requestId: '123456-1',
};
const cli = fileURLToPath(new URL('../../cli/dispatch-native-build.mjs', import.meta.url));

test('native dispatcher defaults to profile refresh and forwards explicit false without changing build identity', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'expo-drafts-dispatch-'));
  try {
    const bin = join(directory, 'bin');
    await mkdir(bin);
    const argsPath = join(directory, 'args.json');
    await writeFile(join(bin, 'eas'), `#!${process.execPath}\nconst fs=require('node:fs');fs.writeFileSync(process.env.TEST_ARGS_PATH,JSON.stringify(process.argv.slice(2)));process.stdout.write(JSON.stringify({id:'10000000-1111-2222-3333-444444444444'}));\n`, { mode: 0o755 });
    const input = join(directory, 'request.json');
    const output = join(directory, 'run.json');
    await writeFile(input, JSON.stringify(request));
    const env = { ...process.env, PATH: `${bin}${delimiter}${process.env.PATH}`, TEST_ARGS_PATH: argsPath };
    delete env.DRAFT_REFRESH_AD_HOC_PROVISIONING_PROFILE;
    for (const value of [undefined, 'true', 'false']) {
      const invocationEnv = { ...env };
      if (value !== undefined) invocationEnv.DRAFT_REFRESH_AD_HOC_PROVISIONING_PROFILE = value;
      await promisify(execFile)(process.execPath, [cli, input, output], { cwd: directory, env: invocationEnv });
      const args = JSON.parse(await readFile(argsPath, 'utf8'));
      assert.deepEqual(args, [
        'workflow:run', '.eas/workflows/build-draft.yml', '--non-interactive', '--json',
        '--input', `runtime_version=${request.runtimeVersion}`, '--input', `git_commit=${request.gitCommitHash}`,
        '--input', `request_id=${request.requestId}`,
        '--input', `refresh_ad_hoc_provisioning_profile=${value ?? 'true'}`,
      ]);
      assert.equal(JSON.parse(await readFile(output, 'utf8')).id, '10000000-1111-2222-3333-444444444444');
      await rm(argsPath);
      await rm(output);
    }
    for (const value of ['', 'False', '0', 'false\n--input=unexpected']) {
      await assert.rejects(promisify(execFile)(process.execPath, [cli, input, output], {
        cwd: directory, env: { ...env, DRAFT_REFRESH_AD_HOC_PROVISIONING_PROFILE: value },
      }), (error) => /must be exactly true or false/.test(error.stderr));
      await assert.rejects(readFile(argsPath), { code: 'ENOENT' });
      await assert.rejects(readFile(output), { code: 'ENOENT' });
    }
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
