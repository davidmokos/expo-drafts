import assert from 'node:assert/strict';
import { execFile, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import {
  buildCatalogFromEasBuild,
  buildCatalogFromRequest,
  createBuildRequestRecord,
  mergeBuildCatalogs,
  validateBuildCatalog,
} from '../../cli/build-catalog.mjs';

const projectId = 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929';
const buildId = '11223344-5566-7788-99aa-bbccddeeff00';
const runtimeVersion = '4b251db3e96d71fbcd20d1be7d63ddf929309765';
const gitCommitHash = '1751cd545fb14e15b65eec773541ee8e60e9696f';
const options = {
  projectId,
  runtimeVersion,
  gitCommitHash,
  requestId: '34284195380-1',
  requestedAt: '2026-09-09T01:00:00.000Z',
  now: '2026-09-09T02:00:00.000Z',
  requestUrl: 'https://github.com/davidmokos/expo-drafts/issues/5',
  statusUrl: 'https://github.com/davidmokos/expo-drafts/actions/runs/34284195380',
};
// Sanitized shape from the EAS CLI BuildFragment; no real signing metadata.
const build = {
  id: buildId,
  status: 'FINISHED',
  platform: 'IOS',
  app: { id: projectId, slug: 'expo-drafts-lab', ownerAccount: { name: 'mokosdavid' } },
  runtime: { version: runtimeVersion },
  buildProfile: 'drafts-device',
  distribution: 'INTERNAL',
  isForIosSimulator: false,
  gitCommitHash,
  completedAt: '2026-09-09T01:59:00.000Z',
  expirationDate: '2026-10-09T01:59:00.000Z',
  artifacts: {
    applicationArchiveUrl: 'https://expo.dev/artifacts/eas/example.ipa?token=do-not-copy',
  },
  logFiles: ['do-not-copy'],
  initiatingActor: { displayName: 'do-not-copy' },
};
const cli = fileURLToPath(new URL('../../cli/build-catalog.mjs', import.meta.url));
const publisher = fileURLToPath(new URL('../../cli/publish-build-catalog.mjs', import.meta.url));
const draftPublisher = fileURLToPath(new URL('../../cli/publish-catalog.mjs', import.meta.url));

test('finished internal device metadata produces an install page and strips private artifact data', () => {
  const catalog = buildCatalogFromEasBuild(build, options);
  assert.equal(catalog.builds[0].state, 'ready');
  assert.equal(catalog.builds[0].buildId, buildId);
  assert.equal(
    catalog.builds[0].installUrl,
    `https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/${buildId}`
  );
  assert.equal(JSON.stringify(catalog).includes('do-not-copy'), false);
  const { app, runtime, ...legacy } = build;
  assert.deepEqual(
    buildCatalogFromEasBuild({ ...legacy, project: app, runtimeVersion: runtime.version }, options),
    catalog
  );
  assert.deepEqual(
    buildCatalogFromEasBuild({ ...build, project: app, runtimeVersion }, options),
    catalog
  );
  const reused = buildCatalogFromEasBuild({ ...build, gitCommitHash: 'a'.repeat(40) }, options);
  assert.equal(reused.builds[0].gitCommitHash, 'a'.repeat(40));
  assert.throws(
    () =>
      buildCatalogFromEasBuild(
        { ...build, gitCommitHash: 'a'.repeat(40) },
        { ...options, expectedBuildCommit: gitCommitHash }
      ),
    /expected build commit/
  );
  assert.throws(
    () => buildCatalogFromEasBuild(build, { ...options, expectedBuildId: projectId }),
    /expected build ID/
  );
  assert.equal(
    buildCatalogFromEasBuild(
      { ...build, buildProfile: 'preview-iphone' },
      { ...options, profile: 'preview-iphone' }
    ).builds[0].profile,
    'preview-iphone'
  );
  assert.throws(
    () => buildCatalogFromRequest({ ...options, profile: '../invalid', state: 'queued' }),
    /valid profile/
  );
});

test('wrong identity, unknown runtime, simulator, store, and unfinished builds cannot become ready', () => {
  for (const [change, pattern] of [
    [{ app: { ...build.app, id: buildId } }, /different project/],
    [{ project: { ...build.app, id: buildId } }, /different project/],
    [{ project: { ...build.app, slug: 'other-app' } }, /metadata disagree/],
    [{ runtime: null }, /runtime is unknown/],
    [{ runtime: { version: 'wrong' } }, /requested runtimeVersion/],
    [{ runtimeVersion: 'conflicting-legacy-runtime' }, /requested runtimeVersion/],
    [{ platform: 'ANDROID' }, /platform/],
    [{ buildProfile: 'production' }, /profile/],
    [{ distribution: 'STORE' }, /INTERNAL/],
    [{ isForIosSimulator: true }, /physical device/],
    [{ isForIosSimulator: undefined }, /physical device/],
    [{ developmentClient: true }, /development client/],
    [{ status: 'IN_PROGRESS' }, /FINISHED/],
    [{ status: 'ERRORED' }, /FINISHED/],
    [{ artifacts: {} }, /applicationArchiveUrl/],
    [{ artifacts: { applicationArchiveUrl: 'http://expo.dev/app.ipa' } }, /HTTPS/],
    [{ expirationDate: '2026-09-09T00:00:00.000Z' }, /expired/],
    [{ gitCommitHash: 'unknown' }, /full Git commit/],
  ]) {
    assert.throws(() => buildCatalogFromEasBuild({ ...build, ...change }, options), pattern);
  }
});

test('request states and imported catalogs validate identity, URLs, and unique keys', () => {
  const request = buildCatalogFromRequest({ ...options, state: 'queued' });
  assert.equal(createBuildRequestRecord({ ...options, state: 'queued' }).state, 'queued');
  assert.throws(
    () => createBuildRequestRecord({ ...options, state: 'ready' }),
    /ready requires EAS metadata/
  );
  assert.throws(
    () =>
      createBuildRequestRecord({
        ...options,
        state: 'queued',
        installUrl: 'https://expo.dev/test',
      }),
    /Only a ready/
  );
  assert.throws(
    () => createBuildRequestRecord({ ...options, state: 'queued', requestedAt: '2026-10-09' }),
    /precede/
  );
  assert.throws(
    () =>
      createBuildRequestRecord({
        ...options,
        state: 'queued',
        statusUrl: 'https://github.com.evil.test/a/b/issues/1',
      }),
    /GitHub/
  );
  assert.throws(
    () =>
      createBuildRequestRecord({
        ...options,
        state: 'queued',
        requestUrl: 'https://user:secret@github.com/a/b/issues/1',
      }),
    /credentials/
  );
  assert.throws(() => validateBuildCatalog({ ...request, projectId: 'wrong' }), /UUID/);
  assert.throws(() => validateBuildCatalog({ ...request, schemaVersion: 2 }), /schemaVersion/);
  assert.throws(
    () =>
      validateBuildCatalog({ ...request, builds: [{ ...request.builds[0], platform: undefined }] }),
    /require platform/
  );
  assert.throws(
    () => validateBuildCatalog({ ...request, builds: [...request.builds, ...request.builds] }),
    /duplicate/
  );
  const ready = buildCatalogFromEasBuild(build, options);
  for (const url of [
    'https://expo.dev.evil.test/build',
    `https://expo.dev/accounts/a/projects/b/builds/${projectId}`,
  ]) {
    assert.throws(
      () => validateBuildCatalog({ ...ready, builds: [{ ...ready.builds[0], installUrl: url }] }),
      /expo.dev build page/
    );
  }
});

test('late observations never regress final states, while a new attempt can retry failure', () => {
  const queued = buildCatalogFromRequest({ ...options, state: 'queued' });
  const building = buildCatalogFromRequest({ ...options, state: 'building' });
  const failed = buildCatalogFromRequest({ ...options, state: 'failed' });
  const ready = buildCatalogFromEasBuild(build, options);
  assert.equal(mergeBuildCatalogs(building, queued).builds[0].state, 'building');
  assert.equal(mergeBuildCatalogs(failed, building).builds[0].state, 'failed');
  assert.equal(mergeBuildCatalogs(ready, failed).builds[0].state, 'ready');
  assert.equal(mergeBuildCatalogs(failed, ready).builds[0].state, 'ready');
  const retry = buildCatalogFromRequest({
    ...options,
    requestId: '34284195380-2',
    requestedAt: '2026-09-09T01:30:00.000Z',
    state: 'queued',
  });
  assert.equal(mergeBuildCatalogs(failed, retry).builds[0].requestId, retry.builds[0].requestId);
  const staleFailure = buildCatalogFromRequest({
    ...options,
    state: 'failed',
    now: '2026-09-10T00:00:00.000Z',
  });
  assert.equal(mergeBuildCatalogs(retry, staleFailure).builds[0].state, 'queued');
  assert.equal(mergeBuildCatalogs(ready, retry).builds[0].state, 'ready');
  const newerReady = buildCatalogFromEasBuild(
    { ...build, id: projectId },
    { ...options, requestId: '34284195380-2', requestedAt: '2026-09-09T01:30:00.000Z' }
  );
  assert.equal(mergeBuildCatalogs(ready, newerReady).builds[0].buildId, projectId);
  assert.equal(mergeBuildCatalogs(newerReady, ready).builds[0].buildId, projectId);
  assert.throws(
    () => mergeBuildCatalogs(ready, { ...ready, projectId: buildId }),
    /different EAS projects/
  );
  assert.throws(
    () =>
      mergeBuildCatalogs(
        ready,
        buildCatalogFromRequest({
          ...options,
          state: 'queued',
          requestedAt: '2026-09-09T01:01:00.000Z',
        })
      ),
    /different requestedAt/
  );
  assert.throws(
    () => mergeBuildCatalogs(ready, buildCatalogFromEasBuild({ ...build, id: projectId }, options)),
    /different EAS builds/
  );
});

test('build CLI writes validated request and EAS records without changing output on invalid input', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'expo-build-cli-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const input = join(dir, 'eas.json');
  const output = join(dir, 'builds.json');
  await writeFile(input, JSON.stringify({ ...build, expirationDate: null }));
  const flags = [
    '--output',
    output,
    '--project-id',
    projectId,
    '--runtime-version',
    runtimeVersion,
    '--git-commit',
    gitCommitHash,
    '--request-id',
    options.requestId,
    '--requested-at',
    options.requestedAt,
  ];
  execFileSync(process.execPath, [cli, 'request', ...flags, '--state', 'building'], {
    stdio: 'pipe',
  });
  assert.equal(JSON.parse(await readFile(output, 'utf8')).builds[0].state, 'building');
  execFileSync(process.execPath, [cli, 'build', ...flags, '--input', input], { stdio: 'pipe' });
  const valid = await readFile(output, 'utf8');
  assert.equal(JSON.parse(valid).builds[0].state, 'ready');
  await writeFile(input, JSON.stringify({ ...build, runtime: null }));
  assert.throws(
    () =>
      execFileSync(process.execPath, [cli, 'build', ...flags, '--input', input], { stdio: 'pipe' }),
    /runtime is unknown/
  );
  assert.equal(await readFile(output, 'utf8'), valid);
});

test('concurrent build and update writers preserve both files and all runtime keys on a shared branch', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'expo-build-git-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const remote = join(dir, 'remote.git');
  execFileSync('git', ['init', '--bare', remote], { stdio: 'pipe' });
  const repos = Array.from({ length: 5 }, (_, i) => join(dir, `clone-${i}`));
  for (const repo of repos) execFileSync('git', ['clone', remote, repo], { stdio: 'pipe' });
  // Seed only catalog.json, exercising the missing build-catalog.json path.
  const draft = {
    schemaVersion: 1,
    projectId,
    generatedAt: options.now,
    drafts: [
      {
        id: projectId,
        name: 'Preview',
        channel: 'draft-pr-1',
        createdAt: options.now,
        updates: [{ id: buildId, groupId: projectId, platform: 'ios', runtimeVersion }],
      },
    ],
  };
  const draftInput = join(dir, 'draft.json');
  await writeFile(draftInput, JSON.stringify(draft));
  execFileSync(
    process.execPath,
    [draftPublisher, '--input', draftInput, '--repository', repos[0]],
    { stdio: 'pipe' }
  );
  const run = promisify(execFile);
  const jobs = await Promise.all(
    repos.slice(0, 4).map(async (repo, i) => {
      const input = join(dir, `request-${i}.json`);
      await writeFile(
        input,
        JSON.stringify(
          buildCatalogFromRequest({ ...options, state: 'queued', runtimeVersion: `runtime-${i}` })
        )
      );
      return run(process.execPath, [publisher, '--input', input, '--repository', repo]);
    })
  );
  assert.equal(jobs.length, 4);
  const newerDraft = { ...draft, drafts: [{ ...draft.drafts[0], channel: 'draft-pr-2' }] };
  await writeFile(draftInput, JSON.stringify(newerDraft));
  const readyInput = join(dir, 'ready.json');
  await writeFile(readyInput, JSON.stringify(buildCatalogFromEasBuild(build, options)));
  const staleInput = join(dir, 'stale-building.json');
  await writeFile(
    staleInput,
    JSON.stringify(buildCatalogFromRequest({ ...options, state: 'building' }))
  );
  await Promise.all([
    run(process.execPath, [publisher, '--input', readyInput, '--repository', repos[0]]),
    run(process.execPath, [publisher, '--input', staleInput, '--repository', repos[1]]),
    run(process.execPath, [draftPublisher, '--input', draftInput, '--repository', repos[4]]),
  ]);
  const gitShow = (file) =>
    JSON.parse(
      execFileSync('git', ['--git-dir', remote, 'show', `drafts-catalog:${file}`], {
        encoding: 'utf8',
      })
    );
  const finalBuilds = validateBuildCatalog(gitShow('build-catalog.json'));
  assert.equal(finalBuilds.builds.length, 5);
  assert.equal(
    finalBuilds.builds.find((entry) => entry.runtimeVersion === runtimeVersion).state,
    'ready'
  );
  assert.deepEqual(
    gitShow('catalog.json')
      .drafts.map((entry) => entry.channel)
      .sort(),
    ['draft-pr-1', 'draft-pr-2']
  );
  for (const repo of repos)
    assert.equal(
      execFileSync('git', ['status', '--porcelain'], { cwd: repo, encoding: 'utf8' }),
      ''
    );
});

test('update publisher initializes catalog.json when a build catalog created the branch first', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'expo-build-first-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const remote = join(dir, 'remote.git');
  const repo = join(dir, 'clone');
  execFileSync('git', ['init', '--bare', remote], { stdio: 'pipe' });
  execFileSync('git', ['clone', remote, repo], { stdio: 'pipe' });
  const requestFile = join(dir, 'build.json');
  await writeFile(
    requestFile,
    JSON.stringify(buildCatalogFromRequest({ ...options, state: 'queued' }))
  );
  execFileSync(process.execPath, [publisher, '--input', requestFile, '--repository', repo], {
    stdio: 'pipe',
  });
  const emptyDraftFile = join(dir, 'draft.json');
  await writeFile(
    emptyDraftFile,
    JSON.stringify({ schemaVersion: 1, projectId, generatedAt: options.now, drafts: [] })
  );
  execFileSync(
    process.execPath,
    [draftPublisher, '--input', emptyDraftFile, '--repository', repo],
    { stdio: 'pipe' }
  );
  const files = execFileSync(
    'git',
    ['--git-dir', remote, 'ls-tree', '--name-only', 'drafts-catalog'],
    { encoding: 'utf8' }
  );
  assert.equal(files, 'build-catalog.json\ncatalog.json\n');
});
