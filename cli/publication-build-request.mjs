import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { setTimeout } from 'node:timers/promises';
import {
  githubJson,
  parseBuildRequest,
  validateBuildRequest,
  fetchBuildRequestSource,
} from './build-request.mjs';
import { createApi, updatesFromWorkflow } from './eas-workflow.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA = /^[0-9a-f]{40}$/i;
const WORKFLOW_PATH = '.github/workflows/drafts.yml';
const MAX_ARTIFACT_BYTES = 1_000_000;
const sameRepo = (value, repository) => value?.toLowerCase() === repository.toLowerCase();
const positiveInteger = (value) => Number.isSafeInteger(value) && value > 0;

/** Only a successful, same-repository PR publication can use privileged build credentials. */
export function validatePublicationRun(event, run, workflow, repository) {
  const trigger = event.workflow_run;
  if (
    event.action !== 'completed' ||
    !positiveInteger(trigger?.id) ||
    !positiveInteger(trigger.run_attempt) ||
    !positiveInteger(run?.run_attempt) ||
    trigger.id !== run?.id ||
    !positiveInteger(event.repository?.id) ||
    !positiveInteger(workflow?.id) ||
    trigger.event !== 'pull_request' ||
    trigger.status !== 'completed' ||
    trigger.conclusion !== 'success' ||
    !sameRepo(trigger.head_repository?.full_name, repository) ||
    !sameRepo(event.repository?.full_name, repository) ||
    !sameRepo(run.repository?.full_name, repository) ||
    !sameRepo(run.head_repository?.full_name, repository) ||
    run.repository?.id !== event.repository.id ||
    run.head_repository?.id !== event.repository.id ||
    run.event !== 'pull_request' ||
    run.path !== WORKFLOW_PATH ||
    workflow?.path !== WORKFLOW_PATH ||
    run.workflow_id !== workflow.id ||
    run.name !== 'Publish PR draft' ||
    trigger.head_sha !== run.head_sha ||
    !SHA.test(run.head_sha ?? '')
  ) {
    throw new Error('Not a verified successful PR publication from this repository.');
  }
  // A completion event from an older attempt must not consume a newer attempt's artifact.
  if (run.run_attempt > trigger.run_attempt) return null;
  if (run.run_attempt !== trigger.run_attempt)
    throw new Error('Publication attempt differs from GitHub.');
  if (run.status !== 'completed' || run.conclusion !== 'success')
    throw new Error('Publication did not complete successfully.');
  const prs = run.pull_requests;
  if (
    !Array.isArray(prs) ||
    prs.length !== 1 ||
    !positiveInteger(prs[0].number) ||
    !SHA.test(prs[0].head?.sha ?? '') ||
    prs[0].head?.repo?.id !== event.repository.id ||
    prs[0].base?.repo?.id !== event.repository.id
  ) {
    throw new Error('Publication does not identify one same-repository PR and exact source.');
  }
  // GitHub updates a historical run's PR association to the current PR head,
  // while run.head_sha and artifact.workflow_run.head_sha remain historical.
  if (prs[0].head.sha !== run.head_sha) return null;
  return { number: prs[0].number, source: run.head_sha, runId: run.id, attempt: run.run_attempt };
}

export function validatePublicationReport(report, dispatched, identity, projectId) {
  const draft = report?.drafts?.[0];
  const ios = draft?.updates?.filter((update) => update.platform === 'ios');
  if (
    report?.schemaVersion !== 1 ||
    report.projectId !== projectId ||
    report.drafts?.length !== 1 ||
    draft?.pullRequest?.number !== identity.number ||
    draft.channel !== `draft-pr-${identity.number}` ||
    draft.gitCommitHash !== identity.source ||
    !UUID.test(draft.id ?? '') ||
    ios?.length !== 1 ||
    !UUID.test(dispatched?.id ?? '')
  ) {
    throw new Error('Publication report does not match the trusted PR, project, and source.');
  }
  const request = parseBuildRequest(
    `\`\`\`expo-drafts-build-request\n${JSON.stringify({
      schemaVersion: 1,
      projectId,
      channel: draft.channel,
      updateId: ios[0].id,
      runtimeVersion: ios[0].runtimeVersion,
      gitCommitHash: identity.source,
    })}\n\`\`\``
  );
  return { request, groupId: draft.id, runId: dispatched.id };
}

/** Read two bounded JSON members in memory; never extract or execute upstream artifact files. */
export async function readPublicationArtifact(
  run,
  repository,
  { github = githubJson, token = process.env.GH_TOKEN, fetchImpl = fetch } = {}
) {
  const listing = await github(
    `/repos/${repository}/actions/runs/${run.id}/artifacts?per_page=100`
  );
  const matches = listing.artifacts?.filter((artifact) => artifact.name === 'draft-catalog-entry');
  const artifact = matches?.[0];
  if (
    !token ||
    listing.total_count > 100 ||
    matches?.length !== 1 ||
    !positiveInteger(artifact.id) ||
    artifact.expired !== false ||
    !Number.isSafeInteger(artifact.size_in_bytes) ||
    artifact.size_in_bytes < 1 ||
    artifact.size_in_bytes > MAX_ARTIFACT_BYTES ||
    artifact.workflow_run?.id !== run.id ||
    artifact.workflow_run?.head_sha !== run.head_sha ||
    artifact.workflow_run?.repository_id !== run.repository.id ||
    artifact.workflow_run?.head_repository_id !== run.repository.id
  ) {
    throw new Error('Missing or ambiguous publication artifact for the verified run.');
  }
  const response = await fetchImpl(
    `https://api.github.com/repos/${repository}/actions/artifacts/${artifact.id}/zip`,
    {
      headers: { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json' },
      redirect: 'manual',
      signal: AbortSignal.timeout(30000),
    }
  );
  if (response.status !== 302) throw new Error('GitHub did not provide the publication artifact.');
  let url;
  try {
    url = new URL(response.headers.get('location'));
  } catch {
    /* Reject below. */
  }
  if (!url || url.protocol !== 'https:' || url.username || url.password)
    throw new Error('Invalid artifact download location.');
  // Signed artifact URLs receive no GitHub or Expo credentials.
  const download = await fetchImpl(url.href, {
    redirect: 'error',
    signal: AbortSignal.timeout(30000),
  });
  if (!download.ok || !download.body) throw new Error('Could not read the publication artifact.');
  const chunks = [];
  let size = 0;
  for await (const chunk of download.body) {
    size += chunk.length;
    if (size > MAX_ARTIFACT_BYTES) throw new Error('Publication artifact is too large.');
    chunks.push(chunk);
  }
  const directory = await mkdtemp(join(tmpdir(), 'expo-drafts-publication-'));
  try {
    const archive = join(directory, 'report.zip');
    await writeFile(archive, Buffer.concat(chunks), { mode: 0o600 });
    const names = spawnSync('unzip', ['-Z1', archive], { encoding: 'utf8', maxBuffer: 4000 });
    if (
      names.status !== 0 ||
      names.stdout.trim().split('\n').sort().join('\n') !== 'draft.json\neas-workflow.json'
    ) {
      throw new Error('Publication artifact must contain only the two expected JSON reports.');
    }
    const documents = ['draft.json', 'eas-workflow.json'].map((name) => {
      const content = spawnSync('unzip', ['-p', archive, name], {
        encoding: 'utf8',
        maxBuffer: 100_000,
      });
      if (content.status !== 0 || content.error)
        throw new Error('Could not read bounded publication JSON.');
      try {
        return JSON.parse(content.stdout);
      } catch {
        throw new Error('Invalid publication JSON.');
      }
    });
    return { report: documents[0], dispatched: documents[1] };
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

export async function buildRequestFromPublication(
  event,
  {
    repository,
    projectId,
    github = githubJson,
    artifact = readPublicationArtifact,
    fetchSource = fetchBuildRequestSource,
    fetchRun = (id) => createApi(process.env.EXPO_TOKEN).fetchRun(id),
    sleep = (ms) => setTimeout(ms),
  } = {}
) {
  if (!positiveInteger(event.workflow_run?.id)) throw new Error('Missing publication run ID.');
  const [run, workflow] = await Promise.all([
    github(`/repos/${repository}/actions/runs/${event.workflow_run.id}`),
    github(`/repos/${repository}/actions/workflows/drafts.yml`),
  ]);
  const identity = validatePublicationRun(event, run, workflow, repository);
  if (!identity) return null;
  const pr = await github(`/repos/${repository}/pulls/${identity.number}`);
  if (
    pr.number !== identity.number ||
    !sameRepo(pr.head?.repo?.full_name, repository) ||
    !sameRepo(pr.base?.repo?.full_name, repository)
  )
    throw new Error('Publication PR belongs to another repository.');
  if (pr.state !== 'open' || pr.head.sha !== identity.source) return null;
  let documents;
  try {
    documents = await artifact(run, repository);
  } catch {
    throw new Error('Could not read the verified publication artifact.');
  }
  const { report, dispatched } = documents;
  const publication = validatePublicationReport(report, dispatched, identity, projectId);
  let easRun;
  for (let attempt = 0; ; attempt += 1) {
    try {
      easRun = await fetchRun(publication.runId);
      break;
    } catch (error) {
      if (error.retryable === false || attempt === 2)
        throw new Error('Could not verify the EAS publication workflow.');
      await sleep(1000 * 2 ** attempt);
    }
  }
  if (easRun.inputs?.github_run_id !== String(identity.runId))
    throw new Error('EAS publication belongs to another GitHub run.');
  const updates = updatesFromWorkflow(easRun, {
    runId: publication.runId,
    projectId,
    channel: publication.request.channel,
    gitCommit: identity.source,
  }).filter((update) => update.platform === 'ios');
  if (
    updates.length !== 1 ||
    updates[0].id !== publication.request.updateId ||
    updates[0].group !== publication.groupId ||
    updates[0].runtimeVersion !== publication.request.runtimeVersion
  ) {
    throw new Error('Publication report differs from the actual EAS update output.');
  }
  const app = await fetchSource(projectId, publication.request.channel);
  let verified;
  try {
    verified = validateBuildRequest(publication.request, app, { projectId, permission: 'write' });
  } catch (error) {
    if (error.message.startsWith('This preview changed.')) return null;
    throw error;
  }
  const commit = await github(`/repos/${repository}/commits/${identity.source}`);
  if (commit.sha !== identity.source)
    throw new Error('Published source is unavailable in this repository.');
  return verified;
}
