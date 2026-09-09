import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parse } from 'yaml';
import {
  buildRequestFromPublication,
  readPublicationArtifact,
  validatePublicationRun,
} from '../../cli/publication-build-request.mjs';
import { nativeBuildConcurrencyKey, profileRefreshForEvent } from '../../cli/build-request.mjs';

const repository = 'davidmokos/expo-drafts';
const projectId = 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929';
const id = '01a0876c-09c4-7ecf-ae27-6c53c1071c55';
const group = '01a0876c-09c4-7ecf-ae27-6c53c1071c66';
const easId = '01a0876a-a50e-7ae4-b6e9-7cb129daabfc';
const branch = '01a082cf-2c74-7f83-ae12-f415ed032d56';
const sha = '92121ecb0403922dc73bd892306381f73debd596';
const runtime = 'native-runtime-a';
const repo = { id: 1361809994, full_name: repository };
const run = {
  id: 34388756318,
  run_attempt: 1,
  head_sha: sha,
  name: 'Publish PR draft',
  path: '.github/workflows/drafts.yml',
  workflow_id: 353447623,
  event: 'pull_request',
  status: 'completed',
  conclusion: 'success',
  repository: repo,
  head_repository: repo,
  pull_requests: [{ number: 2, head: { sha, repo }, base: { repo } }],
};
const workflow = { id: run.workflow_id, path: run.path };
const event = { action: 'completed', repository: repo, workflow_run: run };
const pr = { number: 2, state: 'open', head: { sha, repo }, base: { repo } };
const report = {
  schemaVersion: 1,
  projectId,
  drafts: [
    {
      id: group,
      channel: 'draft-pr-2',
      gitCommitHash: sha,
      pullRequest: { number: 2 },
      updates: [{ id, platform: 'ios', runtimeVersion: runtime }],
    },
  ],
};
const eas = {
  id: easId,
  status: 'SUCCESS',
  workflow: { fileName: 'publish-draft.yml', app: { id: projectId } },
  inputs: { channel: 'draft-pr-2', git_commit: sha, github_run_id: String(run.id) },
  jobs: [
    {
      key: 'publish_update',
      type: 'UPDATE',
      status: 'SUCCESS',
      outputs: {
        updates_json: JSON.stringify([
          { id, group, platform: 'ios', runtimeVersion: runtime, gitCommitHash: sha },
        ]),
      },
    },
  ],
};
const app = {
  id: projectId,
  updateChannelByName: {
    name: 'draft-pr-2',
    isPaused: false,
    branchMapping: JSON.stringify({
      version: 0,
      data: [{ branchId: branch, branchMappingLogic: 'true' }],
    }),
    updateBranches: [
      {
        id: branch,
        updates: [
          {
            id,
            group,
            platform: 'ios',
            runtime: { version: runtime },
            gitCommitHash: sha,
            message: 'EAS verified title',
            isRollBackToEmbedded: false,
            rolloutPercentage: null,
            rolloutControlUpdate: null,
          },
        ],
      },
    ],
  },
};
const listing = {
  total_count: 1,
  artifacts: [
    {
      id: 10118861005,
      name: 'draft-catalog-entry',
      expired: false,
      size_in_bytes: 1000,
      workflow_run: {
        id: run.id,
        head_sha: sha,
        repository_id: repo.id,
        head_repository_id: repo.id,
      },
    },
  ],
};
function dependencies(overrides = {}) {
  return {
    repository,
    projectId,
    github: async (path) => {
      if (path.endsWith(`/actions/runs/${run.id}`)) return structuredClone(run);
      if (path.endsWith('/actions/workflows/drafts.yml')) return structuredClone(workflow);
      if (path.endsWith('/pulls/2')) return structuredClone(pr);
      if (path.endsWith(`/commits/${sha}`)) return { sha };
      throw new Error('Unexpected GitHub lookup');
    },
    artifact: async () => ({ report: structuredClone(report), dispatched: { id: easId } }),
    fetchRun: async () => structuredClone(eas),
    fetchSource: async () => structuredClone(app),
    ...overrides,
  };
}

test('completed same-repo publication verifies EAS workflow plus current channel before requesting native source', async () => {
  const request = await buildRequestFromPublication(event, dependencies());
  assert.deepEqual(request, {
    schemaVersion: 1,
    projectId,
    updateId: id,
    channel: 'draft-pr-2',
    runtimeVersion: runtime,
    gitCommitHash: sha,
    name: 'EAS verified title',
    pullRequest: 2,
    platform: 'ios',
    profile: 'drafts-device',
  });
});

test('rejects failed, fork, unrelated workflow, ambiguous PR, and mismatched run identities', () => {
  for (const change of [
    { conclusion: 'failure' },
    { status: 'in_progress' },
    { event: 'push' },
    { path: '.github/workflows/other.yml' },
    { workflow_id: 123 },
    { head_sha: 'a'.repeat(40) },
    { head_repository: { ...repo, full_name: 'fork/expo-drafts' } },
    { head_repository: { ...repo, id: repo.id + 1 } },
    { repository: { ...repo, full_name: 'another/repository' } },
    { pull_requests: [] },
    { pull_requests: [...run.pull_requests, ...run.pull_requests] },
    { pull_requests: [{ number: 2, head: { sha, repo: { id: 1 } }, base: { repo } }] },
  ])
    assert.throws(() => validatePublicationRun(event, { ...run, ...change }, workflow, repository));
  assert.throws(() =>
    validatePublicationRun({ ...event, action: 'requested' }, run, workflow, repository)
  );
  assert.throws(() =>
    validatePublicationRun(
      { ...event, workflow_run: { ...run, run_attempt: 2 } },
      run,
      workflow,
      repository
    )
  );
  assert.equal(
    validatePublicationRun(
      event,
      { ...run, run_attempt: 2, status: 'in_progress', conclusion: null },
      workflow,
      repository
    ),
    null
  );
  assert.equal(
    validatePublicationRun(
      event,
      {
        ...run,
        pull_requests: [{ ...run.pull_requests[0], head: { sha: 'b'.repeat(40), repo } }],
      },
      workflow,
      repository
    ),
    null
  );
});

test('superseded or closed PRs skip before artifact, Expo access, or source checkout', async () => {
  for (const changedPR of [
    { ...pr, state: 'closed' },
    { ...pr, head: { ...pr.head, sha: 'b'.repeat(40) } },
  ]) {
    const deps = dependencies();
    const original = deps.github;
    deps.github = async (path) => (path.endsWith('/pulls/2') ? changedPR : original(path));
    deps.artifact = async () => assert.fail('stale publication must not read an artifact');
    deps.fetchRun = async () => assert.fail('stale publication must not access Expo');
    assert.equal(await buildRequestFromPublication(event, deps), null);
  }
});

test('untrusted artifact cannot select another project, PR, source, runtime, or EAS update', async () => {
  const mutations = [
    (r) => {
      r.projectId = id;
    },
    (r) => {
      r.drafts[0].pullRequest.number = 3;
    },
    (r) => {
      r.drafts[0].channel = 'draft-pr-3';
    },
    (r) => {
      r.drafts[0].gitCommitHash = 'a'.repeat(40);
    },
    (r) => {
      r.drafts[0].updates[0].runtimeVersion = 'different-native';
    },
    (r) => {
      r.drafts[0].updates[0].id = group;
    },
    (r) => {
      r.drafts[0].id = id;
    },
    (r) => {
      r.drafts[0].updates[0].platform = 'android';
    },
  ];
  for (const mutate of mutations) {
    const changed = structuredClone(report);
    mutate(changed);
    await assert.rejects(
      buildRequestFromPublication(
        event,
        dependencies({
          artifact: async () => ({ report: changed, dispatched: { id: easId } }),
        })
      )
    );
  }
  const anotherRun = structuredClone(eas);
  anotherRun.inputs.github_run_id = '987';
  await assert.rejects(
    buildRequestFromPublication(event, dependencies({ fetchRun: async () => anotherRun })),
    /another GitHub run/
  );
});

test('a later actual EAS publication skips the old one, while a wrong EAS project fails closed', async () => {
  const newer = structuredClone(app);
  newer.updateChannelByName.updateBranches[0].updates[0].id = group;
  assert.equal(
    await buildRequestFromPublication(event, dependencies({ fetchSource: async () => newer })),
    null
  );
  await assert.rejects(
    buildRequestFromPublication(event, dependencies({ fetchSource: async () => ({ ...app, id }) })),
    /another EAS project/
  );
});

test('transient EAS read retries preserve publication identity and cannot dispatch or cancel a build', async () => {
  const calls = [],
    waits = [];
  await buildRequestFromPublication(
    event,
    dependencies({
      fetchRun: async (value) => {
        calls.push(value);
        if (calls.length < 3) throw new Error('temporary');
        return eas;
      },
      sleep: async (ms) => waits.push(ms),
    })
  );
  assert.deepEqual(calls, [easId, easId, easId]);
  assert.deepEqual(waits, [1000, 2000]);
});

async function zipReport(directory, extra = false) {
  await writeFile(join(directory, 'draft.json'), JSON.stringify(report));
  await writeFile(join(directory, 'eas-workflow.json'), JSON.stringify({ id: easId }));
  const names = ['draft.json', 'eas-workflow.json'];
  if (extra) {
    await writeFile(join(directory, 'unexpected.mjs'), 'throw new Error("must never execute")');
    names.push('unexpected.mjs');
  }
  const archive = join(directory, extra ? 'extra.zip' : 'report.zip');
  execFileSync('zip', ['-q', archive, ...names], { cwd: directory });
  return readFile(archive);
}
function artifactFetch(zip, calls = []) {
  return async (url, options) => {
    calls.push({ url, options });
    if (url.startsWith('https://api.github.com/'))
      return new Response(null, {
        status: 302,
        headers: { location: 'https://artifacts.example.test/report.zip?private-signature' },
      });
    return new Response(zip);
  };
}

test('artifact is read only as bounded JSON without extracting files or forwarding credentials', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'expo-drafts-report-test-'));
  try {
    const zip = await zipReport(directory),
      calls = [];
    const value = await readPublicationArtifact(run, repository, {
      github: async () => listing,
      token: 'test-only-gh',
      fetchImpl: artifactFetch(zip, calls),
    });
    assert.deepEqual(value, { report, dispatched: { id: easId } });
    assert.equal(calls[0].options.headers.authorization, 'Bearer test-only-gh');
    assert.equal(calls[1].options.headers, undefined);
    assert.equal(calls[1].options.redirect, 'error');
    await assert.rejects(
      readPublicationArtifact(run, repository, {
        github: async () => listing,
        token: 'test-only-gh',
        fetchImpl: artifactFetch(await zipReport(directory, true)),
      }),
      /only the two expected/
    );
    for (const bad of [
      { ...listing, artifacts: [...listing.artifacts, ...listing.artifacts] },
      { ...listing, artifacts: [{ ...listing.artifacts[0], expired: true }] },
      { ...listing, artifacts: [{ ...listing.artifacts[0], size_in_bytes: 1_000_001 }] },
      {
        ...listing,
        artifacts: [
          {
            ...listing.artifacts[0],
            workflow_run: { ...listing.artifacts[0].workflow_run, head_sha: 'a'.repeat(40) },
          },
        ],
      },
    ])
      await assert.rejects(
        readPublicationArtifact(run, repository, {
          github: async () => bad,
          token: 'test-only',
          fetchImpl: async () => assert.fail('must not download'),
        })
      );
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test('runtime concurrency shares JS-only requests but separates native/profile/project changes; automatic profile reuse is explicit', () => {
  const request = {
    projectId,
    runtimeVersion: runtime,
    profile: 'drafts-device',
    platform: 'ios',
    gitCommitHash: sha,
    channel: 'draft-pr-2',
  };
  const key = nativeBuildConcurrencyKey(request);
  assert.match(key, /^expo-drafts-native-[0-9a-f]{64}$/);
  assert.equal(
    nativeBuildConcurrencyKey({ ...request, gitCommitHash: 'b'.repeat(40), channel: 'draft-pr-3' }),
    key
  );
  for (const change of [
    { runtimeVersion: 'native-b' },
    { platform: 'android' },
    { profile: 'other' },
    { projectId: id },
  ])
    assert.notEqual(nativeBuildConcurrencyKey({ ...request, ...change }), key);
  assert.equal(profileRefreshForEvent(event), 'false');
  assert.equal(profileRefreshForEvent({ issue: {} }), 'true');
  assert.equal(profileRefreshForEvent({ inputs: {} }), 'true');
  assert.equal(
    profileRefreshForEvent({ inputs: { refresh_ad_hoc_provisioning_profile: false } }),
    'false'
  );
  assert.throws(() =>
    profileRefreshForEvent({ inputs: { refresh_ad_hoc_provisioning_profile: 'FALSE' } })
  );
});

test('workflow uses independent completion trigger, trusted validation, and a non-canceling runtime lock around EAS lookup/create', async () => {
  const yaml = parse(
    await readFile(new URL('../../.github/workflows/native-build.yml', import.meta.url), 'utf8')
  );
  assert.deepEqual(yaml.on.workflow_run, { workflows: ['Publish PR draft'], types: ['completed'] });
  assert.equal(yaml.permissions.actions, 'read');
  assert.equal(yaml.jobs.build.concurrency['cancel-in-progress'], false);
  assert.equal(yaml.jobs.build.concurrency.group, '${{ needs.validate.outputs.concurrency_key }}');
  assert.match(yaml.jobs.build.if, /should_build == 'true'/);
  assert.equal(
    yaml.jobs.validate.steps.find((s) => s.uses?.startsWith('actions/checkout')).with.ref,
    '${{ github.event.repository.default_branch }}'
  );
  const build = parse(
    await readFile(new URL('../../example/.eas/workflows/build-draft.yml', import.meta.url), 'utf8')
  );
  assert.equal(build.jobs.existing_build.params.wait_for_in_progress, true);
  assert.equal(build.jobs.existing_build.params.runtime_version, '${{ inputs.runtime_version }}');
  assert.equal(build.jobs.native_build.if, '${{ !needs.existing_build.outputs.build_id }}');
  assert.equal(build.concurrency.cancel_in_progress, false);
});

test('automatic request CLI validates the full bridge and cleanly suppresses a superseded PR', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'expo-drafts-auto-request-'));
  try {
    const zip = await zipReport(directory);
    const eventPath = join(directory, 'event.json'),
      output = join(directory, 'request.json');
    const outputVariables = join(directory, 'outputs');
    await writeFile(eventPath, JSON.stringify(event));
    const preload = join(directory, 'mock-api.mjs');
    await writeFile(
      preload,
      `globalThis.fetch = async (url, options) => {
      let value;
      if(url==='https://api.expo.dev/graphql') value=JSON.parse(options.body).query.includes('DraftWorkflow')?${JSON.stringify({ data: { workflowRuns: { byId: eas } } })}:${JSON.stringify({ data: { app: { byId: app } } })};
      else if(url.includes('/actions/artifacts/')) return new Response(null,{status:302,headers:{location:'https://artifacts.example.test/report.zip'}});
      else if(url.startsWith('https://artifacts.example.test/')) return new Response(Buffer.from('${zip.toString('base64')}','base64'));
      else if(url.endsWith('/artifacts?per_page=100')) value=${JSON.stringify(listing)};
      else if(url.endsWith('/actions/runs/${run.id}')) value=${JSON.stringify(run)};
      else if(url.endsWith('/actions/workflows/drafts.yml')) value=${JSON.stringify(workflow)};
      else if(url.endsWith('/pulls/2')) {value=${JSON.stringify(pr)};if(process.env.TEST_MOVED) value.head.sha='b'.repeat(40);}
      else if(url.endsWith('/commits/${sha}')) value={sha:'${sha}'};
      else throw new Error('Unexpected URL');
      return new Response(JSON.stringify(value));
    };`
    );
    const cli = fileURLToPath(new URL('../../cli/build-request.mjs', import.meta.url));
    const env = {
      ...process.env,
      GH_TOKEN: 'test-only-gh',
      EXPO_TOKEN: 'test-only-expo',
      GITHUB_RUN_ID: '456',
      GITHUB_RUN_ATTEMPT: '1',
      GITHUB_OUTPUT: outputVariables,
    };
    const args = [
      '--import',
      preload,
      cli,
      '--repository',
      repository,
      '--project-id',
      projectId,
      '--event-file',
      eventPath,
      '--output',
      output,
    ];
    await promisify(execFile)(process.execPath, args, { env, cwd: directory });
    const actual = JSON.parse(await readFile(output, 'utf8'));
    assert.equal(actual.updateId, id);
    assert.equal(actual.gitCommitHash, sha);
    assert.match(await readFile(outputVariables, 'utf8'), /should_build=true/);
    assert.match(await readFile(outputVariables, 'utf8'), /refresh_profile=false/);
    await rm(output);
    await rm(outputVariables);
    await promisify(execFile)(process.execPath, args, {
      env: { ...env, TEST_MOVED: '1' },
      cwd: directory,
    });
    assert.equal(await readFile(outputVariables, 'utf8'), 'should_build=false\n');
    await assert.rejects(readFile(output), { code: 'ENOENT' });
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
