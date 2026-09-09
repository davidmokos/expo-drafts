#!/usr/bin/env node
import { readFile, writeFile, appendFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { spawnSync } from 'node:child_process';
import { setTimeout } from 'node:timers/promises';
import { workflowQuery } from './eas-workflow.mjs';
import { buildCatalogFromRequest, buildCatalogFromEasBuild } from './build-catalog.mjs';
import { publishBuildCatalog } from './publish-build-catalog.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function validateNativeBuildWorkflow(run, expected) {
  if (run.id !== expected.runId || run.workflow?.app?.id !== expected.projectId ||
    run.workflow?.fileName !== 'build-draft.yml' || run.inputs?.runtime_version !== expected.runtimeVersion ||
    run.inputs?.git_commit !== expected.gitCommitHash || run.inputs?.request_id !== expected.requestId) {
    throw new Error('EAS build workflow does not match the requested project, runtime, and source.');
  }
}

export function buildFromWorkflow(run, expected) {
  validateNativeBuildWorkflow(run, expected);
  if (run.status !== 'SUCCESS') throw new Error(`EAS native build workflow ended with ${run.status}.`);
  const created = run.jobs?.find((job) => job.key === 'native_build' && job.status === 'SUCCESS');
  const reused = run.jobs?.find((job) => job.key === 'existing_build' && job.status === 'SUCCESS');
  const job = created ?? reused;
  const output = job?.outputs;
  if (job?.type !== (created ? 'BUILD' : 'GET_BUILD') ||
    !UUID.test(output?.build_id ?? '') || output.runtime_version !== expected.runtimeVersion ||
    output.platform !== 'ios' || output.profile !== expected.profile || output.distribution !== 'internal' ||
    ![false, 'false'].includes(output.simulator) ||
    (created && output.git_commit_hash !== expected.gitCommitHash)) {
    throw new Error('EAS returned a build that does not match the requested iPhone runtime and profile.');
  }
  return { id: output.build_id, reused: !created };
}

export async function waitForNativeBuild(expected, {
  fetchRun, onState = async () => {}, sleep = (ms) => setTimeout(ms), now = Date.now,
  timeoutMs = 125 * 60 * 1000, pollMs = 20000,
}) {
  const deadline = now() + timeoutMs;
  let previousState;
  let failures = 0;
  while (now() < deadline) {
    let run;
    try { run = await fetchRun(expected.runId); }
    catch (error) {
      if (error.retryable === false) throw error;
      failures += 1;
      await sleep(Math.min(pollMs * 2 ** Math.min(failures - 1, 2), 60000, deadline - now()));
      continue;
    }
    failures = 0;
    validateNativeBuildWorkflow(run, expected);
    if (['SUCCESS', 'FAILURE', 'CANCELED'].includes(run.status)) return buildFromWorkflow(run, expected);
    const state = run.status === 'NEW' ? 'queued' : 'building';
    if (state !== previousState) { await onState(state); previousState = state; }
    await sleep(Math.min(pollMs, deadline - now()));
  }
  // Keep the EAS job alive so a later request can discover/reuse its result.
  throw new Error('Timed out observing the build. Open the workflow link to check its current status.');
}

async function fetchRun(runId) {
  if (!process.env.EXPO_TOKEN) throw new Error('EXPO_TOKEN is required to observe EAS builds.');
  const response = await fetch('https://api.expo.dev/graphql', {
    method: 'POST', headers: { authorization: `Bearer ${process.env.EXPO_TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ query: workflowQuery, variables: { runId } }), signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) {
    const error = new Error(`EAS build observation returned HTTP ${response.status}.`);
    error.retryable = response.status === 429 || response.status >= 500;
    throw error;
  }
  const result = await response.json();
  if (!result.data?.workflowRuns?.byId || result.errors?.length) {
    const error = new Error('EAS rejected build observation.');
    error.retryable = result.errors?.some((error) => error.extensions?.isTransient) ?? false;
    throw error;
  }
  return result.data.workflowRuns.byId;
}

async function main() {
  const { values, positionals } = parseArgs({ allowPositionals: true, options: {
    request: { type: 'string' }, 'run-file': { type: 'string' }, repository: { type: 'string' },
    state: { type: 'string' }, output: { type: 'string' },
    'project-directory': { type: 'string' },
  } });
  const command = positionals[0];
  if (positionals.length !== 1 || !['state', 'wait'].includes(command) || !values.request) {
    throw new Error('Use state|wait --request FILE --repository DIR [--state STATE] [--run-file FILE].');
  }
  const request = JSON.parse(await readFile(values.request, 'utf8'));
  const publish = async (input) => publishBuildCatalog({ input, repository: values.repository ?? '.' });
  if (command === 'state') {
    await publish(buildCatalogFromRequest({ ...request, state: values.state, updatedAt: new Date().toISOString() }));
    return;
  }
  const dispatched = JSON.parse(await readFile(values['run-file'], 'utf8'));
  const runId = dispatched.id ?? dispatched.workflowRun?.id;
  if (!UUID.test(runId ?? '')) throw new Error('EAS did not return a workflow run ID.');
  const expected = { ...request, runId };
  const built = await waitForNativeBuild(expected, {
    fetchRun,
    onState: async (state) => {
      await publish(buildCatalogFromRequest({ ...request, state, updatedAt: new Date().toISOString() }));
      process.stdout.write(`Native build is ${state}.\n`);
    },
  });
  const view = spawnSync('eas', ['build:view', built.id, '--json'], {
    cwd: values['project-directory'] ?? '.', encoding: 'utf8', maxBuffer: 5_000_000,
  });
  if (view.error || view.status !== 0) throw new Error('Could not verify the finished EAS build metadata.');
  const catalog = buildCatalogFromEasBuild(JSON.parse(view.stdout), {
    ...request, updatedAt: new Date().toISOString(),
    expectedBuildId: built.id,
    expectedBuildCommit: built.reused ? undefined : request.gitCommitHash,
  });
  await publish(catalog);
  if (values.output) await writeFile(values.output, `${JSON.stringify(catalog, null, 2)}\n`);
  const build = catalog.builds[0];
  if (process.env.GITHUB_STEP_SUMMARY) {
    await appendFile(process.env.GITHUB_STEP_SUMMARY,
      `Compatible iPhone build ${built.reused ? 'reused' : 'created'}: [Install](${build.installUrl})\n\nRuntime: \`${build.runtimeVersion}\`\n`);
  }
  process.stdout.write(`Compatible build is ready: ${build.installUrl}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => { process.stderr.write(`expo-drafts: ${error.message}\n`); process.exitCode = 1; });
}
