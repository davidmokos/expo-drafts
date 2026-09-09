import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseBuildRequest, validateBuildRequest, fetchBuildRequestSource } from '../../cli/build-request.mjs';

const projectId = 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929';
const updateId = '01a08311-7c39-7dc5-bcc8-ded78524f3e6';
const branchId = '01a082cf-2c74-7f83-ae12-f415ed032d56';
const sha = '892fb51f8e6f3eaa76b9b3ed1a7de44728b9b2db';
const request = { schemaVersion: 1, projectId, updateId, channel: 'draft-pr-2', runtimeVersion: 'native-a', name: 'Untrusted request title' };
const app = { id: projectId, updateChannelByName: {
  id: '01a082cf-2d17-79b6-9bd1-e273be954b19', name: 'draft-pr-2', isPaused: false,
  branchMapping: JSON.stringify({ version: 0, data: [{ branchId, branchMappingLogic: 'true' }] }),
  updateBranches: [{ id: branchId, name: 'draft-pr-2', updates: [{
    id: updateId, group: 'b01e9978-0f86-4f3d-bb2e-6e16fb91df6a', message: 'Actual EAS title',
    platform: 'ios', runtime: { version: 'native-a' }, gitCommitHash: sha,
    isRollBackToEmbedded: false, rolloutPercentage: null, rolloutControlUpdate: null,
  }] }],
} };
const body = (value) => `Please build this preview.\n\n\`\`\`expo-drafts-build-request\n${JSON.stringify(value)}\n\`\`\``;
const verify = (value = app, input = request) => validateBuildRequest(input, value, { projectId, permission: 'write' });
const update = (value) => value.updateChannelByName.updateBranches[0].updates[0];

test('request CLI uses EAS plus trusted GitHub source and rejects a moved PR without any hosted catalog', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'expo-drafts-build-request-'));
  const repository = 'davidmokos/expo-drafts';
  try {
    const event = join(directory, 'event.json');
    await writeFile(event, JSON.stringify({
      repository: { full_name: repository }, sender: { login: 'davidmokos' },
      inputs: { channel: request.channel, update_id: updateId, runtime_version: request.runtimeVersion },
    }));
    const preload = join(directory, 'mock-api.mjs');
    await writeFile(preload, `globalThis.fetch = async (url) => {
      let result;
      if (url === 'https://api.expo.dev/graphql') result = ${JSON.stringify({ data: { app: { byId: app } } })};
      else if (url.endsWith('/collaborators/davidmokos/permission')) result = {permission:'write'};
      else if (url.endsWith('/pulls/2')) result = {head:{repo:{full_name:${JSON.stringify(repository)}},sha:process.env.TEST_PR_SHA}};
      else if (url.endsWith('/commits/${sha}')) result = {sha:${JSON.stringify(sha)}};
      else throw new Error('Unexpected API endpoint: ' + url);
      return {ok:true,json:async()=>result};
    };\n`);
    const output = join(directory, 'request.json');
    const args = [
      '--import', preload, fileURLToPath(new URL('../../cli/build-request.mjs', import.meta.url)),
      '--event-file', event, '--repository', repository, '--project-id', projectId, '--output', output,
    ];
    const env = {
      ...process.env, GH_TOKEN: 'test-gh-only', EXPO_TOKEN: 'test-expo-only',
      GITHUB_RUN_ID: '123456', GITHUB_RUN_ATTEMPT: '2', GITHUB_OUTPUT: join(directory, 'outputs'), TEST_PR_SHA: sha,
    };
    await promisify(execFile)(process.execPath, args, { cwd: directory, env });
    const verified = JSON.parse(await readFile(output, 'utf8'));
    assert.equal(verified.gitCommitHash, sha);
    assert.equal(verified.name, 'Actual EAS title');
    assert.equal(verified.requestId, '123456-2');
    assert.equal(verified.statusUrl, `https://github.com/${repository}/actions/runs/123456`);
    await rm(output);
    await assert.rejects(promisify(execFile)(process.execPath, args, {
      cwd: directory, env: { ...env, TEST_PR_SHA: 'a'.repeat(40) },
    }), (error) => /PR source changed/.test(error.stderr));
    await assert.rejects(readFile(output), { code: 'ENOENT' });
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('uses authenticated permission and current EAS source, not request name or arbitrary SHA', () => {
  const verified = verify(app, parseBuildRequest(body(request)));
  assert.equal(verified.name, 'Actual EAS title');
  assert.equal(verified.gitCommitHash, sha);
  assert.equal(verified.profile, 'drafts-device');
  assert.equal(verified.pullRequest, 2);
  for (const permission of ['read', 'triage', 'none', undefined]) {
    assert.throws(() => validateBuildRequest(request, app, { projectId, permission }), /write access/);
  }
  assert.throws(() => verify(app, { ...request, gitCommitHash: 'a'.repeat(40) }), /source commit/);
  const manual = structuredClone(app);
  manual.updateChannelByName.name = 'draft-manual';
  update(manual).message = ' ';
  assert.equal(verify(manual, { ...request, channel: 'draft-manual' }).name, 'draft-manual');
  assert.equal(verify(manual, { ...request, channel: 'draft-manual' }).pullRequest, undefined);
});

test('rejects stale updates, wrong runtime/project, and ambiguous payloads', () => {
  for (const change of [{ updateId: 'a'.repeat(8) + updateId.slice(8) }, { runtimeVersion: 'native-b' }, { channel: 'draft-pr-3' }]) {
    assert.throws(() => verify(app, { ...request, ...change }), /preview changed/);
  }
  assert.throws(() => verify(app, { ...request, projectId: updateId }), /another EAS project/);
  assert.throws(() => verify({ ...app, id: updateId }), /another EAS project/);
  assert.throws(() => parseBuildRequest(body(request) + '\n' + body(request)), /one expo-drafts/);
  assert.throws(() => parseBuildRequest(body({ ...request, runtimeVersion: 'native-a\noutput=injected' })), /invalid update identity/);
  assert.throws(() => parseBuildRequest(body({ ...request, channel: '$(echo injected)' })), /invalid update identity/);
  const latest = structuredClone(app);
  update(latest).runtime.version = 'new-native-runtime';
  assert.throws(() => verify(latest), /preview changed/);
});

test('rejects paused, ambiguous, unknown, or remapped EAS channel routing', () => {
  const mapping = JSON.parse(app.updateChannelByName.branchMapping);
  for (const change of [
    { isPaused: true }, { isPaused: undefined }, { branchMapping: 'invalid' },
    { branchMapping: JSON.stringify({ ...mapping, version: 1 }) },
    { branchMapping: JSON.stringify({ ...mapping, data: [] }) },
    { branchMapping: JSON.stringify({ ...mapping, data: [...mapping.data, ...mapping.data] }) },
    { branchMapping: JSON.stringify({ ...mapping, data: [{ branchId, branchMappingLogic: true }] }) },
    { branchMapping: JSON.stringify({ ...mapping, data: [{ branchId: updateId, branchMappingLogic: 'true' }] }) },
    { updateBranches: [...app.updateChannelByName.updateBranches, ...app.updateChannelByName.updateBranches] },
  ]) {
    assert.throws(() => verify({ ...app, updateChannelByName: { ...app.updateChannelByName, ...change } }), /route directly/);
  }
});

test('rejects rollback, partial rollout, Android, missing source, and malformed update identity', () => {
  for (const change of [
    { isRollBackToEmbedded: true }, { isRollBackToEmbedded: undefined },
    { rolloutPercentage: 30 }, { rolloutPercentage: '100' }, { rolloutControlUpdate: { id: updateId } },
    { platform: 'android' }, { id: 'invalid' }, { group: 'invalid' }, { gitCommitHash: null },
  ]) {
    const source = structuredClone(app);
    Object.assign(update(source), change);
    assert.throws(() => verify(source), /rollout|preview changed|source commit/);
  }
  const completed = structuredClone(app);
  update(completed).rolloutPercentage = 100;
  assert.equal(verify(completed).updateId, updateId);
});

test('EAS source lookup retries the same channel after a transient failure and never filters out new runtimes', async () => {
  const calls = [];
  const sleeps = [];
  const result = await fetchBuildRequestSource(projectId, 'draft-pr-2', {
    token: 'test-only', sleep: async (ms) => sleeps.push(ms),
    fetchImpl: async (url, options) => {
      const query = JSON.parse(options.body);
      calls.push({ url, query });
      assert.equal(options.headers.authorization, 'Bearer test-only');
      if (calls.length === 1) throw new Error('temporary network failure');
      if (calls.length === 2) return { ok: false, status: 503 };
      return { ok: true, json: async () => ({ data: { app: { byId: app } } }) };
    },
  });
  assert.deepEqual(result, app);
  assert.deepEqual(sleeps, [1000, 2000]);
  assert.equal(calls.length, 3);
  assert.ok(calls.every(({ url, query }) => url === 'https://api.expo.dev/graphql' &&
    query.variables.appId === projectId && query.variables.channelName === 'draft-pr-2'));
  assert.doesNotMatch(calls[0].query.query, /runtimeVersions/);
  assert.equal(verify(result).gitCommitHash, sha);
});

test('EAS source lookup fails closed on denied access, partial GraphQL data, and exhausted network errors', async () => {
  await assert.rejects(fetchBuildRequestSource(projectId, request.channel, { token: '' }), /EXPO_TOKEN/);
  for (const response of [
    { ok: false, status: 401 },
    { ok: true, json: async () => ({ data: { app: { byId: app } }, errors: [{ message: 'private details' }] }) },
    { ok: true, json: async () => ({ data: { app: { byId: null } } }) },
  ]) {
    let calls = 0;
    await assert.rejects(fetchBuildRequestSource(projectId, request.channel, {
      token: 'test-only', sleep: async () => assert.fail('must not retry denied or incomplete data'),
      fetchImpl: async () => { calls += 1; return response; },
    }), /Could not verify/);
    assert.equal(calls, 1);
  }
  let calls = 0;
  await assert.rejects(fetchBuildRequestSource(projectId, request.channel, {
    token: 'test-only', sleep: async () => {},
    fetchImpl: async () => { calls += 1; throw new Error('secret transport detail'); },
  }), (error) => !error.message.includes('secret') && /Could not verify/.test(error.message));
  assert.equal(calls, 3);
});
