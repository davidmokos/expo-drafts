#!/usr/bin/env node
import { appendFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { setTimeout } from 'node:timers/promises';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA = /^[0-9a-f]{40}$/i;
const TERMINAL = new Set(['SUCCESS', 'FAILURE', 'CANCELED']);

export const workflowQuery = `query DraftWorkflow($runId: ID!) {
  workflowRuns { byId(workflowRunId: $runId) {
    id status inputs
    workflow { fileName app { id } }
    jobs { key type status outputs }
  } }
}`;

export const cancelMutation = `mutation CancelDraftWorkflow($runId: ID!) {
  workflowRun { cancelWorkflowRun(workflowRunId: $runId) { id } }
}`;

export function validateWorkflowIdentity(run, expected) {
  if (run.id !== expected.runId || run.workflow?.app?.id !== expected.projectId) {
    throw new Error('EAS workflow does not belong to the requested run and project.');
  }
  if (
    run.workflow.fileName !== 'publish-draft.yml' ||
    run.inputs?.channel !== expected.channel ||
    run.inputs?.git_commit !== expected.gitCommit
  ) {
    throw new Error('EAS workflow inputs do not match this draft and source commit.');
  }
}

export function updatesFromWorkflow(run, expected) {
  validateWorkflowIdentity(run, expected);
  if (run.status !== 'SUCCESS') throw new Error(`EAS workflow finished with status ${run.status}.`);
  const job = run.jobs?.find((job) => job.key === 'publish_update');
  if (
    job?.type !== 'UPDATE' ||
    job.status !== 'SUCCESS' ||
    typeof job.outputs?.updates_json !== 'string'
  ) {
    throw new Error('EAS publish_update job did not return successful updates_json output.');
  }
  const updates = JSON.parse(job.outputs.updates_json);
  if (
    !Array.isArray(updates) ||
    !updates.length ||
    updates.some(
      (update) =>
        update.gitCommitHash !== expected.gitCommit ||
        !UUID.test(update.id) ||
        !UUID.test(update.group)
    )
  ) {
    throw new Error('Published EAS updates do not match the uploaded source commit.');
  }
  return updates;
}

export async function waitForWorkflow(
  expected,
  {
    fetchRun,
    cancelRun,
    sleep = (milliseconds, signal) => setTimeout(milliseconds, undefined, { signal }),
    now = Date.now,
    signal,
    onStatus = () => {},
    onRetry = () => {},
    timeoutMs = 45 * 60 * 1000,
    pollMs = 15000,
  }
) {
  const deadline = now() + timeoutMs;
  let previousStatus;
  let verified = false;
  let terminal = false;
  let timedOut = false;
  let readFailures = 0;
  const checkDeadline = () => {
    if (now() >= deadline) {
      timedOut = true;
      throw new Error('Timed out waiting for EAS publication.');
    }
  };
  try {
    while (!signal?.aborted) {
      checkDeadline();
      let run;
      try {
        run = await fetchRun(expected.runId);
      } catch (error) {
        if (error.retryable === false) throw error;
        checkDeadline();
        readFailures += 1;
        onRetry(readFailures);
        const backoff = Math.min(
          pollMs * 2 ** Math.min(readFailures - 1, 3),
          60000,
          deadline - now()
        );
        await sleep(backoff, signal);
        continue;
      }
      readFailures = 0;
      validateWorkflowIdentity(run, expected);
      verified = true;
      terminal = TERMINAL.has(run.status);
      if (run.status !== previousStatus) {
        onStatus(run.status);
        previousStatus = run.status;
      }
      if (terminal) return updatesFromWorkflow(run, expected);
      checkDeadline();
      await sleep(Math.min(pollMs, deadline - now()), signal);
    }
    throw new Error('Interrupted while waiting for EAS publication.');
  } finally {
    if (verified && !terminal && (timedOut || signal?.aborted)) await cancelRun(expected.runId);
  }
}

function createApi(token) {
  if (!token) throw new Error('EXPO_TOKEN is required to read or cancel this EAS workflow.');
  const request = async (query, runId) => {
    const response = await fetch('https://api.expo.dev/graphql', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${token}` },
      body: JSON.stringify({ query, variables: { runId } }),
      signal: AbortSignal.timeout(30000),
    });
    if (!response.ok) {
      const error = new Error(`EAS workflow API returned HTTP ${response.status}.`);
      error.retryable = response.status === 429 || response.status >= 500;
      throw error;
    }
    const result = await response.json();
    if (result.errors?.length || !result.data) {
      const error = new Error('EAS workflow API rejected the request.');
      error.retryable = result.errors?.some((error) => error.extensions?.isTransient) ?? false;
      throw error;
    }
    return result.data;
  };
  return {
    fetchRun: async (runId) => (await request(workflowQuery, runId)).workflowRuns.byId,
    cancelRun: async (runId) => {
      await request(cancelMutation, runId);
    },
  };
}

async function main() {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: Object.fromEntries(
      ['run-file', 'output', 'project-id', 'channel', 'git-commit'].map((name) => [
        name,
        { type: 'string' },
      ])
    ),
  });
  const command = positionals[0];
  if (positionals.length !== 1 || !['wait', 'cancel'].includes(command) || !values['run-file']) {
    throw new Error(
      'Usage: eas-workflow.mjs wait|cancel --run-file FILE --project-id UUID --channel NAME --git-commit SHA [--output FILE]'
    );
  }
  let dispatched;
  try {
    dispatched = JSON.parse(await readFile(values['run-file'], 'utf8'));
  } catch (error) {
    if (command === 'cancel' && error.code === 'ENOENT') return;
    throw error;
  }
  const expected = {
    runId: dispatched.id,
    projectId: values['project-id'],
    channel: values.channel,
    gitCommit: values['git-commit'],
  };
  if (
    !UUID.test(expected.runId) ||
    !UUID.test(expected.projectId) ||
    !SHA.test(expected.gitCommit) ||
    !expected.channel
  ) {
    throw new Error('Valid workflow/project IDs, channel, and source commit are required.');
  }
  const url = new URL(dispatched.url);
  if (url.protocol !== 'https:' || url.hostname !== 'expo.dev' || url.username || url.password) {
    throw new Error('EAS dispatch returned an unexpected workflow URL.');
  }
  const api = createApi(process.env.EXPO_TOKEN);
  if (command === 'cancel') {
    const run = await api.fetchRun(expected.runId);
    validateWorkflowIdentity(run, expected);
    if (!TERMINAL.has(run.status)) await api.cancelRun(expected.runId);
    return;
  }
  if (!values.output) throw new Error('--output is required when waiting for a publication.');
  process.stdout.write(`EAS workflow: ${url.href}\n`);
  if (process.env.GITHUB_STEP_SUMMARY) {
    await appendFile(
      process.env.GITHUB_STEP_SUMMARY,
      `EAS publication: [view workflow](${url.href})\n\n`
    );
  }
  const controller = new AbortController();
  const interrupt = () => controller.abort();
  process.once('SIGINT', interrupt);
  process.once('SIGTERM', interrupt);
  try {
    const updates = await waitForWorkflow(expected, {
      ...api,
      signal: controller.signal,
      onStatus: (status) => process.stdout.write(`EAS workflow status: ${status}\n`),
      onRetry: () =>
        process.stdout.write('EAS status temporarily unavailable; retrying the same run.\n'),
    });
    const output = resolve(values.output);
    await mkdir(dirname(output), { recursive: true });
    await writeFile(output, `${JSON.stringify(updates, null, 2)}\n`);
    process.stdout.write(`EAS published ${updates.length} platform update(s).\n`);
  } finally {
    process.removeListener('SIGINT', interrupt);
    process.removeListener('SIGTERM', interrupt);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => {
    process.stderr.write(`expo-drafts: ${error.message}\n`);
    process.exitCode = 1;
  });
}
