import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import {
  buildFromWorkflow,
  validateNativeBuildWorkflow,
  waitForNativeBuild,
} from '../../cli/eas-native-build.mjs';
import { buildCatalogFromEasBuild } from '../../cli/build-catalog.mjs';

const expected = {
  runId: '10000000-1111-2222-3333-444444444444',
  projectId: 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929',
  runtimeVersion: '4b251db3e96d71fbcd20d1be7d63ddf929309765',
  gitCommitHash: '1751cd545fb14e15b65eec773541ee8e60e9696f',
  requestId: '34284195380-1',
  requestedAt: '2026-09-09T01:00:00.000Z',
  profile: 'drafts-device',
  now: '2026-09-09T02:00:00.000Z',
};
const buildId = '22334455-6677-8899-aabb-ccddeeff0011';
const output = {
  build_id: buildId,
  runtime_version: expected.runtimeVersion,
  git_commit_hash: expected.gitCommitHash,
  platform: 'ios',
  profile: 'drafts-device',
  distribution: 'internal',
  simulator: 'false',
};
const run = {
  id: expected.runId,
  status: 'SUCCESS',
  workflow: { fileName: 'build-draft.yml', app: { id: expected.projectId } },
  inputs: {
    runtime_version: expected.runtimeVersion,
    git_commit: expected.gitCommitHash,
    request_id: expected.requestId,
  },
  jobs: [{ key: 'native_build', type: 'BUILD', status: 'SUCCESS', outputs: output }],
};
const metadata = {
  id: buildId,
  status: 'FINISHED',
  platform: 'IOS',
  project: {
    id: expected.projectId,
    slug: 'expo-drafts-lab',
    ownerAccount: { name: 'mokosdavid' },
  },
  runtimeVersion: expected.runtimeVersion,
  gitCommitHash: expected.gitCommitHash,
  buildProfile: expected.profile,
  distribution: 'INTERNAL',
  isForIosSimulator: false,
  completedAt: '2026-09-09T01:59:00.000Z',
  artifacts: { applicationArchiveUrl: 'https://expo.dev/artifacts/eas/example.ipa' },
};

test('native workflow identity binds the project, file, source, runtime, and request', () => {
  validateNativeBuildWorkflow(run, expected);
  for (const key of ['runId', 'projectId', 'gitCommitHash', 'runtimeVersion', 'requestId']) {
    assert.throws(
      () => validateNativeBuildWorkflow(run, { ...expected, [key]: 'wrong' }),
      /does not match/
    );
  }
  assert.throws(
    () =>
      validateNativeBuildWorkflow(
        { ...run, workflow: { ...run.workflow, fileName: 'other.yml' } },
        expected
      ),
    /does not match/
  );
});

test('native workflow rejects simulator, store, wrong profile/runtime, and spoofed job outputs', () => {
  assert.deepEqual(buildFromWorkflow(run, expected), { id: buildId, reused: false });
  for (const patch of [
    { runtime_version: 'wrong' },
    { platform: 'android' },
    { profile: 'production' },
    { distribution: 'store' },
    { simulator: 'true' },
    { simulator: 'unknown' },
    { build_id: 'invalid' },
    { git_commit_hash: 'a'.repeat(40) },
  ]) {
    assert.throws(
      () =>
        buildFromWorkflow(
          { ...run, jobs: [{ ...run.jobs[0], outputs: { ...output, ...patch } }] },
          expected
        ),
      /does not match/
    );
  }
  assert.throws(
    () => buildFromWorkflow({ ...run, jobs: [{ ...run.jobs[0], type: 'CUSTOM' }] }, expected),
    /does not match/
  );
  assert.throws(
    () =>
      buildFromWorkflow(
        {
          ...run,
          jobs: [{ key: 'existing_build', type: 'GET_BUILD', status: 'SUCCESS', outputs: {} }],
        },
        expected
      ),
    /does not match/
  );
});

test('a fresh build requires the requested commit while an exact-runtime older build can be reused', () => {
  const olderCommit = 'a'.repeat(40);
  const reuseRun = {
    ...run,
    jobs: [
      {
        key: 'existing_build',
        type: 'GET_BUILD',
        status: 'SUCCESS',
        outputs: { ...output, git_commit_hash: olderCommit },
      },
    ],
  };
  const reused = buildFromWorkflow(reuseRun, expected);
  assert.deepEqual(reused, { id: buildId, reused: true });
  const ready = buildCatalogFromEasBuild(
    { ...metadata, gitCommitHash: olderCommit },
    {
      ...expected,
      expectedBuildId: reused.id,
      expectedBuildCommit: reused.reused ? undefined : expected.gitCommitHash,
    }
  );
  assert.equal(ready.builds[0].state, 'ready');
  assert.equal(ready.builds[0].gitCommitHash, olderCommit);
  assert.throws(
    () =>
      buildCatalogFromEasBuild(
        { ...metadata, gitCommitHash: olderCommit },
        { ...expected, expectedBuildId: buildId, expectedBuildCommit: expected.gitCommitHash }
      ),
    /expected build commit/
  );
  assert.throws(
    () =>
      buildCatalogFromEasBuild(
        { ...metadata, runtimeVersion: 'wrong' },
        { ...expected, expectedBuildId: buildId }
      ),
    /requested runtimeVersion/
  );
});

test('real device BUILD outputs may omit simulator, but ready still requires explicit device metadata', async () => {
  const fixture = JSON.parse(
    await readFile(new URL('./fixtures/native-device-build.json', import.meta.url), 'utf8')
  );
  for (const simulator of [undefined, null]) {
    const actualRun = {
      ...run,
      id: fixture.expected.runId,
      inputs: {
        runtime_version: fixture.expected.runtimeVersion,
        git_commit: fixture.expected.gitCommitHash,
        request_id: fixture.expected.requestId,
      },
      jobs: [{ ...run.jobs[0], outputs: { ...fixture.outputs, simulator } }],
    };
    const built = buildFromWorkflow(actualRun, fixture.expected);
    const verification = {
      ...fixture.expected,
      expectedBuildId: built.id,
      expectedBuildCommit: fixture.expected.gitCommitHash,
    };
    assert.equal(buildCatalogFromEasBuild(fixture.metadata, verification).builds[0].state, 'ready');
    for (const isForIosSimulator of [undefined, null, true]) {
      assert.throws(
        () => buildCatalogFromEasBuild({ ...fixture.metadata, isForIosSimulator }, verification),
        /physical device/
      );
    }
    assert.throws(
      () =>
        buildCatalogFromEasBuild({ ...fixture.metadata, runtimeVersion: 'wrong' }, verification),
      /requested runtimeVersion/
    );
    assert.throws(
      () =>
        buildCatalogFromEasBuild(
          { ...fixture.metadata, gitCommitHash: 'a'.repeat(40) },
          verification
        ),
      /expected build commit/
    );
  }
});

test('native waiter retries transient observations of the same run and reports state transitions', async () => {
  let now = 0;
  let calls = 0;
  const ids = [];
  const states = [];
  const sleeps = [];
  const result = await waitForNativeBuild(expected, {
    now: () => now,
    timeoutMs: 200,
    pollMs: 10,
    sleep: async (ms) => {
      sleeps.push(ms);
      now += ms;
    },
    onState: async (state) => states.push(state),
    fetchRun: async (id) => {
      ids.push(id);
      calls += 1;
      if (calls < 3) throw new Error('temporary network failure');
      return { ...run, status: calls === 3 ? 'NEW' : calls === 4 ? 'IN_PROGRESS' : 'SUCCESS' };
    },
  });
  assert.deepEqual(result, { id: buildId, reused: false });
  assert.deepEqual(states, ['queued', 'building']);
  assert.equal(new Set(ids).size, 1);
  assert.equal(ids[0], expected.runId);
  assert.deepEqual(sleeps.slice(0, 2), [10, 20]);
});

test('native waiter stops on terminal failures, permanent read errors, or identity changes', async () => {
  for (const status of ['FAILURE', 'CANCELED']) {
    await assert.rejects(
      waitForNativeBuild(expected, { fetchRun: async () => ({ ...run, status }) }),
      new RegExp(status)
    );
  }
  let calls = 0;
  const permanent = new Error('not authorized');
  permanent.retryable = false;
  await assert.rejects(
    waitForNativeBuild(expected, {
      fetchRun: async () => {
        calls++;
        throw permanent;
      },
    }),
    /not authorized/
  );
  assert.equal(calls, 1);
  await assert.rejects(
    waitForNativeBuild(expected, { fetchRun: async () => ({ ...run, id: buildId }) }),
    /does not match/
  );
});

test('native waiter bounds observation time without fabricating a ready build', async () => {
  let now = 0;
  const states = [];
  await assert.rejects(
    waitForNativeBuild(expected, {
      now: () => now,
      timeoutMs: 25,
      pollMs: 10,
      fetchRun: async () => ({ ...run, status: 'IN_PROGRESS' }),
      onState: async (state) => states.push(state),
      sleep: async (ms) => {
        now += ms;
      },
    }),
    /Timed out observing/
  );
  assert.equal(now, 25);
  assert.deepEqual(states, ['building']);
});
