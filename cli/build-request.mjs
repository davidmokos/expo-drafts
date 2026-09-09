#!/usr/bin/env node
import { readFile, writeFile, appendFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { setTimeout } from 'node:timers/promises';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA = /^[0-9a-f]{40}$/i;
const RUNTIME = /^[a-zA-Z0-9._-]{1,255}$/;
const REPOSITORY = /^[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+$/;

// Deliberately omit a runtime filter: an older compatible update must never
// replace the latest publication selected in the picker.
export const buildRequestQuery = `query DraftBuildSource($appId: String!, $channelName: String!) {
  app { byId(appId: $appId) {
    id
    updateChannelByName(name: $channelName) {
      id name isPaused branchMapping
      updateBranches(offset: 0, limit: 2) {
        id name
        updates(offset: 0, limit: 1, filter: { platform: IOS }) {
          id group message platform runtime { version }
          gitCommitHash isRollBackToEmbedded
          rolloutPercentage rolloutControlUpdate { id }
        }
      }
    }
  } }
}`;

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

function validatePermission(permission) {
  if (!['admin', 'maintain', 'write'].includes(permission)) {
    throw new Error('Build requests require write access to this repository.');
  }
}

/** Request text is untrusted. EAS supplies the current channel and source. */
export function validateBuildRequest(request, app, { projectId, permission }) {
  validatePermission(permission);
  if (request.projectId.toLowerCase() !== projectId.toLowerCase() ||
    app?.id?.toLowerCase() !== projectId.toLowerCase()) {
    throw new Error('The request or update belongs to another EAS project.');
  }
  const channel = app.updateChannelByName;
  if (!channel || channel.name !== request.channel) {
    throw new Error('This preview changed. Refresh the draft picker and request its current build.');
  }
  let mapping;
  try { mapping = JSON.parse(channel.branchMapping); } catch { /* Reject below. */ }
  const branch = channel.updateBranches?.[0];
  if (channel.isPaused !== false || mapping?.version !== 0 || !Array.isArray(mapping.data) ||
    mapping.data.length !== 1 || mapping.data[0]?.branchMappingLogic !== 'true' ||
    !UUID.test(mapping.data[0]?.branchId ?? '') || !Array.isArray(channel.updateBranches) ||
    channel.updateBranches.length !== 1 || branch?.id?.toLowerCase() !== mapping.data[0].branchId.toLowerCase()) {
    throw new Error('The EAS channel must be active and route directly to one branch without a rollout.');
  }
  const update = branch.updates?.[0];
  if (!Array.isArray(branch.updates) || branch.updates.length !== 1 ||
    !UUID.test(update?.id ?? '') || !UUID.test(update?.group ?? '') || update.platform !== 'ios' ||
    update.id.toLowerCase() !== request.updateId.toLowerCase() ||
    update.runtime?.version !== request.runtimeVersion) {
    throw new Error('This preview changed. Refresh the draft picker and request its current build.');
  }
  if (update.isRollBackToEmbedded !== false ||
    (update.rolloutPercentage != null && update.rolloutPercentage !== 100) || update.rolloutControlUpdate != null) {
    throw new Error('Build requests require a complete EAS publication without a rollout or rollback.');
  }
  if (!SHA.test(update.gitCommitHash ?? '') ||
    (request.gitCommitHash && request.gitCommitHash.toLowerCase() !== update.gitCommitHash.toLowerCase())) {
    throw new Error('The requested preview has no matching source commit in EAS.');
  }
  const prNumber = /^draft-pr-([1-9]\d*)$/.exec(channel.name)?.[1];
  if (prNumber && !Number.isSafeInteger(Number(prNumber))) throw new Error('Invalid PR channel number.');
  return {
    schemaVersion: 1,
    projectId: app.id,
    runtimeVersion: update.runtime.version,
    updateId: update.id,
    channel: channel.name,
    gitCommitHash: update.gitCommitHash,
    name: typeof update.message === 'string' && update.message.trim() ? update.message.trim() : channel.name,
    pullRequest: prNumber ? Number(prNumber) : undefined,
    profile: 'drafts-device',
    platform: 'ios',
  };
}

export async function fetchBuildRequestSource(projectId, channel, {
  token = process.env.EXPO_TOKEN, fetchImpl = fetch, sleep = (ms) => setTimeout(ms),
} = {}) {
  if (!token) throw new Error('EXPO_TOKEN is required to verify published EAS updates.');
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      const response = await fetchImpl('https://api.expo.dev/graphql', {
        method: 'POST', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
        body: JSON.stringify({ query: buildRequestQuery, variables: { appId: projectId, channelName: channel } }),
        signal: AbortSignal.timeout(30000),
      });
      if (!response.ok) {
        const error = new Error(`EAS update verification returned HTTP ${response.status}.`);
        error.retryable = response.status === 429 || response.status >= 500;
        throw error;
      }
      const result = await response.json();
      if (result.errors?.length || !result.data?.app?.byId) {
        const error = new Error('EAS rejected update verification. Check project access and refresh the draft.');
        error.retryable = result.errors?.some((error) => error.extensions?.isTransient) ?? false;
        throw error;
      }
      return result.data.app.byId;
    } catch (error) {
      if (error.retryable === false || attempt === 2) {
        // Do not expose raw network/GraphQL errors, which may contain credentials.
        throw new Error('Could not verify the published update with EAS. Check project access and retry.');
      }
      await sleep(1000 * 2 ** attempt);
    }
  }
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
  validatePermission(access.permission);
  // workflow_dispatch is available for validating the pipeline without a browser.
  const raw = event.issue ? parseBuildRequest(event.issue.body) : {
    schemaVersion: 1, projectId: values['project-id'],
    channel: event.inputs?.channel, updateId: event.inputs?.update_id,
    runtimeVersion: event.inputs?.runtime_version,
  };
  const request = parseBuildRequest(`\`\`\`expo-drafts-build-request\n${JSON.stringify(raw)}\n\`\`\``);
  const app = await fetchBuildRequestSource(values['project-id'], request.channel);
  const verified = validateBuildRequest(request, app, { projectId: values['project-id'], permission: access.permission });
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
