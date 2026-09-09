#!/usr/bin/env node
import { readFile, writeFile, appendFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { validateCatalog } from './catalog.mjs';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA = /^[0-9a-f]{40}$/i;
const RUNTIME = /^[a-zA-Z0-9._-]{1,255}$/;
const REPOSITORY = /^[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+$/;

export function parseBuildRequest(body) {
  if (typeof body !== 'string' || body.length > 16000) throw new Error('Invalid build request body.');
  const blocks = [...body.matchAll(/```expo-drafts-build-request\s*\n([\s\S]*?)\n```/g)];
  if (blocks.length !== 1) throw new Error('Expected one expo-drafts-build-request block.');
  const request = JSON.parse(blocks[0][1]);
  if (!request || request.schemaVersion !== 1 || !UUID.test(request.projectId) ||
    !UUID.test(request.updateId) || !RUNTIME.test(request.runtimeVersion) ||
    typeof request.channel !== 'string' || !/^[a-zA-Z0-9][a-zA-Z0-9._/-]{0,127}$/.test(request.channel) ||
    (request.gitCommitHash !== undefined && !SHA.test(request.gitCommitHash))) {
    throw new Error('The build request contains invalid update identity.');
  }
  return request;
}

/** Request text is untrusted. Only a current catalog entry can select build source. */
export function validateBuildRequest(request, input, { projectId, permission }) {
  if (!['admin', 'maintain', 'write'].includes(permission)) {
    throw new Error('Build requests require write access to this repository.');
  }
  const catalog = validateCatalog(input);
  if (request.projectId.toLowerCase() !== projectId.toLowerCase() ||
    catalog.projectId.toLowerCase() !== projectId.toLowerCase()) {
    throw new Error('The request or catalog belongs to another EAS project.');
  }
  const draft = catalog.drafts.find((draft) => draft.channel === request.channel);
  const update = draft?.updates.find((update) => update.platform === 'ios');
  if (!update || update.id.toLowerCase() !== request.updateId.toLowerCase() ||
    update.runtimeVersion !== request.runtimeVersion) {
    throw new Error('This preview changed. Refresh the draft picker and request its current build.');
  }
  if (!SHA.test(draft.gitCommitHash ?? '') ||
    (request.gitCommitHash && request.gitCommitHash.toLowerCase() !== draft.gitCommitHash.toLowerCase())) {
    throw new Error('The requested preview has no matching source commit in the catalog.');
  }
  return {
    schemaVersion: 1,
    projectId: catalog.projectId,
    runtimeVersion: update.runtimeVersion,
    updateId: update.id,
    channel: draft.channel,
    gitCommitHash: draft.gitCommitHash,
    name: draft.name,
    pullRequest: draft.pullRequest?.number,
    profile: 'drafts-device',
    platform: 'ios',
  };
}

export async function githubJson(path, { token = process.env.GH_TOKEN, fetchImpl = fetch } = {}) {
  if (!token) throw new Error('GH_TOKEN is required to authenticate build requests.');
  const response = await fetchImpl(`https://api.github.com${path}`, {
    headers: { authorization: `Bearer ${token}`, accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) throw new Error(`GitHub rejected build request validation (HTTP ${response.status}).`);
  return response.json();
}

async function main() {
  const { values } = parseArgs({ options: {
    'event-file': { type: 'string' }, output: { type: 'string' },
    repository: { type: 'string' }, 'project-id': { type: 'string' },
  } });
  const repository = values.repository ?? process.env.GITHUB_REPOSITORY;
  if (!REPOSITORY.test(repository ?? '') || !UUID.test(values['project-id'] ?? '') || !values.output) {
    throw new Error('--repository OWNER/REPO --project-id UUID --output FILE are required.');
  }
  const event = JSON.parse(await readFile(values['event-file'] ?? process.env.GITHUB_EVENT_PATH, 'utf8'));
  if (event.repository?.full_name?.toLowerCase() !== repository.toLowerCase()) throw new Error('Wrong request repository.');
  const actor = event.sender?.login;
  if (!/^[a-zA-Z0-9-]+(?:\[bot\])?$/.test(actor ?? '')) throw new Error('Missing GitHub request actor.');
  const access = await githubJson(`/repos/${repository}/collaborators/${encodeURIComponent(actor)}/permission`);
  // workflow_dispatch is available for validating the pipeline without a browser.
  const raw = event.issue ? parseBuildRequest(event.issue.body) : {
    schemaVersion: 1, projectId: values['project-id'],
    channel: event.inputs?.channel, updateId: event.inputs?.update_id,
    runtimeVersion: event.inputs?.runtime_version,
  };
  const request = parseBuildRequest(`\`\`\`expo-drafts-build-request\n${JSON.stringify(raw)}\n\`\`\``);
  const file = await githubJson(`/repos/${repository}/contents/catalog.json?ref=drafts-catalog`);
  if (file.encoding !== 'base64' || typeof file.content !== 'string') throw new Error('Missing draft catalog.');
  const catalog = JSON.parse(Buffer.from(file.content, 'base64').toString('utf8'));
  const verified = validateBuildRequest(request, catalog, { projectId: values['project-id'], permission: access.permission });
  if (verified.pullRequest) {
    const pr = await githubJson(`/repos/${repository}/pulls/${verified.pullRequest}`);
    if (pr.head?.repo?.full_name?.toLowerCase() !== repository.toLowerCase() || pr.head?.sha !== verified.gitCommitHash) {
      throw new Error('The PR source changed or belongs to a fork. Wait for publication and refresh drafts.');
    }
  }
  const commit = await githubJson(`/repos/${repository}/commits/${verified.gitCommitHash}`);
  if (commit.sha !== verified.gitCommitHash) throw new Error('Preview source is unavailable in this repository.');
  const runId = process.env.GITHUB_RUN_ID;
  const attempt = process.env.GITHUB_RUN_ATTEMPT ?? '1';
  if (!/^\d+$/.test(runId ?? '') || !/^\d+$/.test(attempt)) throw new Error('Missing GitHub workflow identity.');
  const issueNumber = event.issue?.number;
  if (issueNumber !== undefined && (!Number.isSafeInteger(issueNumber) || issueNumber < 1)) throw new Error('Invalid issue number.');
  const result = {
    ...verified,
    requestId: `${runId}-${attempt}`, requestedAt: new Date().toISOString(),
    requestUrl: issueNumber ? `https://github.com/${repository}/issues/${issueNumber}` : undefined,
    statusUrl: `https://github.com/${repository}/actions/runs/${runId}`,
  };
  await writeFile(values.output, `${JSON.stringify(result, null, 2)}\n`);
  if (process.env.GITHUB_OUTPUT) {
    await appendFile(process.env.GITHUB_OUTPUT, `git_commit=${result.gitCommitHash}\nruntime=${result.runtimeVersion}\n`);
  }
  process.stdout.write(`Validated build request for ${result.channel}, runtime ${result.runtimeVersion}.\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  main().catch((error) => { process.stderr.write(`expo-drafts: ${error.message}\n`); process.exitCode = 1; });
}
