import test from 'node:test';
import assert from 'node:assert/strict';
import { parseBuildRequest, validateBuildRequest } from '../../cli/build-request.mjs';

const projectId = 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929';
const updateId = '01a08311-7c39-7dc5-bcc8-ded78524f3e6';
const sha = '892fb51f8e6f3eaa76b9b3ed1a7de44728b9b2db';
const request = { schemaVersion: 1, projectId, updateId, channel: 'draft-pr-2', runtimeVersion: 'native-a', name: 'Untrusted request title' };
const catalog = { schemaVersion: 1, projectId, generatedAt: '2026-09-09T00:00:00Z', drafts: [{
  id: 'b01e9978-0f86-4f3d-bb2e-6e16fb91df6a', name: 'Actual catalog title', channel: 'draft-pr-2',
  createdAt: '2026-09-09T00:00:00Z', gitCommitHash: sha,
  pullRequest: { number: 2, url: 'https://github.com/davidmokos/expo-drafts/pull/2' },
  updates: [{ id: updateId, platform: 'ios', runtimeVersion: 'native-a' }],
}] };
const body = (request) => `Please build this preview.\n\n\`\`\`expo-drafts-build-request\n${JSON.stringify(request)}\n\`\`\``;

test('uses authenticated permission and current catalog source, not request name or arbitrary SHA', () => {
  const verified = validateBuildRequest(parseBuildRequest(body(request)), catalog, { projectId, permission: 'write' });
  assert.equal(verified.name, 'Actual catalog title');
  assert.equal(verified.gitCommitHash, sha);
  assert.equal(verified.profile, 'drafts-device');
  for (const permission of ['read', 'triage', 'none', undefined]) {
    assert.throws(() => validateBuildRequest(request, catalog, { projectId, permission }), /write access/);
  }
  assert.throws(() => validateBuildRequest({ ...request, gitCommitHash: 'a'.repeat(40) }, catalog, { projectId, permission: 'admin' }), /source commit/);
});

test('rejects stale updates, wrong runtime/project, and ambiguous payloads', () => {
  for (const change of [{ updateId: 'a'.repeat(8) + updateId.slice(8) }, { runtimeVersion: 'native-b' }, { channel: 'draft-pr-3' }]) {
    assert.throws(() => validateBuildRequest({ ...request, ...change }, catalog, { projectId, permission: 'write' }), /preview changed/);
  }
  assert.throws(() => validateBuildRequest({ ...request, projectId: updateId }, catalog, { projectId, permission: 'write' }), /another EAS project/);
  assert.throws(() => parseBuildRequest(body(request) + '\n' + body(request)), /one expo-drafts/);
  assert.throws(() => parseBuildRequest(body({ ...request, runtimeVersion: 'native-a\noutput=injected' })), /invalid update identity/);
  assert.throws(() => parseBuildRequest(body({ ...request, channel: '$(echo injected)' })), /invalid update identity/);
});
