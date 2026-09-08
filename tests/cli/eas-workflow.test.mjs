import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

import {
  updatesFromWorkflow,
  validateWorkflowIdentity,
  waitForWorkflow,
} from '../../cli/eas-workflow.mjs';

const updates = JSON.parse(
  await readFile(new URL('./fixtures/update.json', import.meta.url), 'utf8')
);
const expected = {
  runId: 'c1a66a49-a495-4243-b7e6-5f43e0e20301',
  projectId: 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929',
  channel: 'draft-pr-42',
  gitCommit: updates[0].gitCommitHash,
};
const successful = {
  id: expected.runId,
  status: 'SUCCESS',
  inputs: { channel: expected.channel, git_commit: expected.gitCommit },
  workflow: { fileName: 'publish-draft.yml', app: { id: expected.projectId } },
  jobs: [
    {
      key: 'publish_update',
      type: 'UPDATE',
      status: 'SUCCESS',
      outputs: { updates_json: JSON.stringify(updates) },
    },
  ],
};

test('extracts full EAS update output, including each platform group and exact runtime', () => {
  assert.deepEqual(updatesFromWorkflow(successful, expected), updates);
});

test('rejects outputs from another project, channel, commit, or unsuccessful publication', () => {
  assert.throws(
    () => validateWorkflowIdentity(successful, { ...expected, projectId: expected.runId }),
    /project/
  );
  assert.throws(
    () => validateWorkflowIdentity(successful, { ...expected, channel: 'draft-pr-99' }),
    /inputs/
  );
  assert.throws(
    () => updatesFromWorkflow({ ...successful, status: 'FAILURE' }, expected),
    /FAILURE/
  );
  assert.throws(() => updatesFromWorkflow({ ...successful, jobs: [] }, expected), /updates_json/);
  const differentCommit = structuredClone(successful);
  differentCommit.jobs[0].outputs.updates_json = JSON.stringify([
    { ...updates[0], gitCommitHash: 'different' },
  ]);
  assert.throws(() => updatesFromWorkflow(differentCommit, expected), /source commit/);
});

test('waits for EAS completion and reports status changes without canceling success', async () => {
  const states = ['NEW', 'IN_PROGRESS', 'IN_PROGRESS', 'SUCCESS'];
  const statuses = [];
  let canceled = false;
  const output = await waitForWorkflow(expected, {
    fetchRun: async () => ({ ...successful, status: states.shift() }),
    cancelRun: async () => {
      canceled = true;
    },
    sleep: async () => {},
    onStatus: (status) => statuses.push(status),
  });
  assert.deepEqual(output, updates);
  assert.deepEqual(statuses, ['NEW', 'IN_PROGRESS', 'SUCCESS']);
  assert.equal(canceled, false);
});

test('cancels the verified EAS run when its GitHub waiter times out', async () => {
  let clock = 0;
  const canceled = [];
  await assert.rejects(
    waitForWorkflow(expected, {
      fetchRun: async () => ({ ...successful, status: 'IN_PROGRESS' }),
      cancelRun: async (id) => {
        canceled.push(id);
      },
      now: () => clock,
      sleep: async () => {
        clock += 10;
      },
      timeoutMs: 20,
    }),
    /Timed out/
  );
  assert.deepEqual(canceled, [expected.runId]);
});

test('transient polling errors retry the same healthy EAS run without canceling it', async () => {
  const queried = [];
  const delays = [];
  let attempt = 0;
  const output = await waitForWorkflow(expected, {
    fetchRun: async (id) => {
      queried.push(id);
      attempt += 1;
      if (attempt === 2 || attempt === 3) throw new Error('Temporary API timeout');
      return { ...successful, status: attempt === 1 ? 'IN_PROGRESS' : 'SUCCESS' };
    },
    cancelRun: async () => {
      assert.fail('A polling error must not cancel publication');
    },
    sleep: async (delay) => {
      delays.push(delay);
    },
    pollMs: 10,
  });
  assert.deepEqual(output, updates);
  assert.deepEqual(queried, Array(4).fill(expected.runId));
  assert.deepEqual(delays, [10, 10, 20]);
});

test('interrupted waiter cancels its EAS run, but does not cancel an unverified run', async () => {
  const controller = new AbortController();
  const canceled = [];
  await assert.rejects(
    waitForWorkflow(expected, {
      fetchRun: async () => ({ ...successful, status: 'IN_PROGRESS' }),
      cancelRun: async (id) => {
        canceled.push(id);
      },
      sleep: async () => {
        controller.abort();
      },
      signal: controller.signal,
    }),
    /Interrupted/
  );
  assert.deepEqual(canceled, [expected.runId]);
  canceled.length = 0;
  await assert.rejects(
    waitForWorkflow(
      { ...expected, projectId: expected.runId },
      {
        fetchRun: async () => ({ ...successful, status: 'IN_PROGRESS' }),
        cancelRun: async (id) => {
          canceled.push(id);
        },
        sleep: async () => {},
      }
    ),
    /project/
  );
  assert.deepEqual(canceled, []);
});

test('a superseded EAS run fails the old GitHub job without producing catalog input', async () => {
  await assert.rejects(
    waitForWorkflow(expected, {
      fetchRun: async () => ({ ...successful, status: 'CANCELED' }),
      cancelRun: async () => {
        assert.fail('Run is already canceled');
      },
    }),
    /CANCELED/
  );
});
