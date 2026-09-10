import test from 'node:test';
import assert from 'node:assert/strict';
import { cp, mkdir, mkdtemp, readFile, realpath, rm, writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';

const root = fileURLToPath(new URL('../../', import.meta.url));
const templates = join(root, 'templates/app-root');
const projectId = '11111111-2222-4333-8444-555555555555';
const workflowId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
const runtime = 'consumer-native-runtime';
const step = (job, name) => {
  const value = job.steps.find((entry) => entry.name === name);
  assert(value?.run, `Missing runnable step: ${name}`);
  return value.run;
};

async function fixture() {
  const dir = await mkdtemp(join(tmpdir(), 'expo-drafts-consumer-'));
  for (const name of [
    'source/.eas/workflows',
    'control/.eas/workflows',
    'work',
    'bin',
    'tooling/node_modules/expo-drafts',
  ]) {
    await mkdir(join(dir, name), { recursive: true });
  }
  await cp(join(root, 'cli'), join(dir, 'tooling/node_modules/expo-drafts/cli'), {
    recursive: true,
  });
  for (const name of ['publish-draft.yml', 'build-draft.yml']) {
    await cp(join(templates, 'eas', name), join(dir, 'control/.eas/workflows', name));
    await writeFile(join(dir, 'source/.eas/workflows', name), 'untrusted PR workflow\n');
  }
  const source = join(dir, 'source');
  const git = (...args) =>
    execFileSync('git', args, {
      cwd: source,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    }).trim();
  git('init');
  git('add', '.');
  git(
    '-c',
    'user.name=Template test',
    '-c',
    'user.email=test@example.invalid',
    'commit',
    '-m',
    'creates consumer fixture'
  );
  const sha = git('rev-parse', 'HEAD');
  await writeFile(
    join(dir, 'bin/npx'),
    `#!/usr/bin/env node
const args = process.argv.slice(2);
if (args.join(' ') === 'expo config --json') {
  process.stdout.write(JSON.stringify({extra:{eas:{projectId:process.env.FIXTURE_PROJECT_ID}}}));
} else if (args.join(' ') === 'expo-updates runtimeversion:resolve --platform ios') {
  process.stdout.write(JSON.stringify({runtimeVersion:process.env.FIXTURE_RUNTIME}));
} else { process.exit(10); }
`,
    { mode: 0o755 }
  );
  await writeFile(
    join(dir, 'bin/eas'),
    `#!/usr/bin/env node
const fs = require('node:fs');
const args = process.argv.slice(2);
fs.writeFileSync(process.env.AUDIT_FILE, JSON.stringify({cwd:process.cwd(),args,workflow:fs.readFileSync(args[1],'utf8')}));
process.stdout.write(JSON.stringify({id:'${workflowId}',url:'https://expo.dev/workflows/${workflowId}'}));
`,
    { mode: 0o755 }
  );
  const env = {
    ...process.env,
    PATH: `${join(dir, 'bin')}:${process.env.PATH}`,
    AUDIT_FILE: join(dir, 'work/dispatch-audit.json'),
    FIXTURE_PROJECT_ID: projectId,
    FIXTURE_RUNTIME: runtime,
    DRAFT_PROJECT_ID: projectId,
    DRAFTS_ENABLED: '1',
    DRAFT_CHANNEL: 'draft-pr-42',
    DRAFT_NAME: 'Consumer preview with spaces',
    DRAFT_HEAD_SHA: sha,
    DRAFT_GITHUB_RUN_ID: '12345',
    EXPECTED_COMMIT: sha,
    EXPECTED_RUNTIME: runtime,
    DRAFT_REFRESH_AD_HOC_PROVISIONING_PROFILE: 'false',
  };
  const shell = (command, overrides = {}) =>
    execFileSync('bash', ['-e', '-o', 'pipefail', '-c', command], {
      cwd: source,
      env: { ...env, ...overrides },
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    });
  return { dir, source, sha, shell, git, cleanup: () => rm(dir, { recursive: true, force: true }) };
}

test('root-app publication uploads the exact PR with trusted workflow and writes outside its archive', async () => {
  const workflow = parse(await readFile(join(templates, 'github/drafts.yml'), 'utf8'));
  const f = await fixture();
  try {
    const command = step(workflow.jobs.update, 'Dispatch the EAS workflow');
    f.shell(command);
    const audit = JSON.parse(await readFile(join(f.dir, 'work/dispatch-audit.json'), 'utf8'));
    const output = JSON.parse(await readFile(join(f.dir, 'work/eas-workflow.json'), 'utf8'));
    assert.equal(audit.cwd, await realpath(f.source));
    assert.equal(audit.workflow, await readFile(join(templates, 'eas/publish-draft.yml'), 'utf8'));
    assert(audit.args.includes(`git_commit=${f.sha}`));
    assert(audit.args.includes('name=Consumer preview with spaces'));
    assert(audit.args.includes('channel=draft-pr-42'));
    assert.equal(output.id, workflowId);
    assert.equal(f.git('rev-parse', 'HEAD'), f.sha);
    assert.throws(() => f.shell(command, { DRAFT_PROJECT_ID: 'another-project' }));
    assert.throws(() => f.shell(command, { DRAFT_HEAD_SHA: 'f'.repeat(40) }));
  } finally {
    await f.cleanup();
  }
});

test('root-app native dispatch uses packaged helpers and rejects a different reproduced runtime', async () => {
  const workflow = parse(await readFile(join(templates, 'github/native-build.yml'), 'utf8'));
  const f = await fixture();
  try {
    const request = {
      schemaVersion: 1,
      projectId,
      platform: 'ios',
      profile: 'drafts-device',
      runtimeVersion: runtime,
      gitCommitHash: f.sha,
      requestId: '12346-1',
    };
    await writeFile(join(f.dir, 'work/request.json'), JSON.stringify(request));
    const verify = step(workflow.jobs.build, 'Verify native runtime and use trusted EAS workflow');
    assert.throws(() => f.shell(verify, { FIXTURE_RUNTIME: 'incompatible-native-runtime' }));
    f.shell(verify);
    f.shell(step(workflow.jobs.build, 'Dispatch EAS native build workflow'));
    const audit = JSON.parse(await readFile(join(f.dir, 'work/dispatch-audit.json'), 'utf8'));
    assert.equal(audit.workflow, await readFile(join(templates, 'eas/build-draft.yml'), 'utf8'));
    assert(audit.args.includes(`runtime_version=${runtime}`));
    assert(audit.args.includes(`git_commit=${f.sha}`));
    assert(audit.args.includes('refresh_ad_hoc_provisioning_profile=false'));
    assert(audit.args.includes('request_id=12346-1'));
    assert.equal(
      JSON.parse(await readFile(join(f.dir, 'work/eas-native-workflow.json'), 'utf8')).id,
      workflowId
    );
    assert.equal(f.git('rev-parse', 'HEAD'), f.sha);
  } finally {
    await f.cleanup();
  }
});
