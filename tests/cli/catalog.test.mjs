import assert from 'node:assert/strict';
import { execFile, execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import test from 'node:test';

import { catalogFromEasUpdates, mergeCatalogs, validateCatalog } from '../../cli/catalog.mjs';

const fixture = JSON.parse(
  await readFile(new URL('./fixtures/update.json', import.meta.url), 'utf8')
);
const cli = fileURLToPath(new URL('../../cli/index.mjs', import.meta.url));
const publisher = fileURLToPath(new URL('../../cli/publish-catalog.mjs', import.meta.url));
const projectId = 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929';
const options = {
  projectId,
  channel: 'draft-pr-42',
  name: 'Improve checkout',
  now: '2026-09-08T13:00:00.000Z',
  pullRequest: { number: 42, url: 'https://github.com/davidmokos/expo-drafts/pull/42' },
};

test('keeps platform runtime fingerprints and split EAS group IDs from one publication', () => {
  const catalog = catalogFromEasUpdates(fixture, options);
  const entry = catalog.drafts[0];
  assert.equal(catalog.projectId, projectId);
  assert.equal(entry.name, options.name);
  assert.equal(entry.channel, options.channel);
  assert.equal(entry.pullRequest.number, 42);
  assert.deepEqual(
    entry.updates,
    [fixture[1], fixture[0]].map((update) => ({
      id: update.id,
      groupId: update.group,
      platform: update.platform,
      runtimeVersion: update.runtimeVersion,
    }))
  );
  assert.equal(JSON.stringify(catalog).includes('manifestPermalink'), false);
  assert.equal(JSON.stringify(catalog).includes('do-not-copy'), false);
  assert.deepEqual(
    catalogFromEasUpdates({ updates: fixture, insights: { secret: 'ignored' } }, options),
    catalog
  );
});

test('rejects rollback directives and records that cannot describe one publication', () => {
  assert.throws(() => catalogFromEasUpdates([], options), /nonempty/);
  assert.throws(
    () => catalogFromEasUpdates([{ ...fixture[0], isRollBackToEmbedded: true }], options),
    /Rollback/
  );
  assert.throws(
    () => catalogFromEasUpdates([fixture[0], fixture[0]], options),
    /one update per platform/
  );
  assert.throws(
    () => catalogFromEasUpdates([{ ...fixture[0], runtimeVersion: '' }], options),
    /runtimeVersion/
  );
  assert.throws(
    () => catalogFromEasUpdates([{ ...fixture[0], platform: 'web' }], options),
    /platform/
  );
  assert.throws(() => catalogFromEasUpdates([{ ...fixture[0], id: 'bad' }], options), /UUID/);
  assert.throws(
    () => catalogFromEasUpdates([fixture[0], { ...fixture[1], branch: 'other' }], options),
    /one branch/
  );
  assert.throws(
    () => catalogFromEasUpdates([fixture[0], { ...fixture[1], gitCommitHash: 'other' }], options),
    /different commits/
  );
  assert.throws(
    () => catalogFromEasUpdates(fixture, { ...options, buildUrl: 'javascript:alert(1)' }),
    /HTTPS/
  );
});

test('out-of-order CI jobs keep latest publication per channel and preserve other PRs', () => {
  const older = catalogFromEasUpdates(fixture, options);
  const newer = catalogFromEasUpdates(
    fixture.map((update) => ({
      ...update,
      createdAt: '2026-09-08T15:00:00.000Z',
      id: update.id.replace('57010', '57020'),
      group: update.group.replace('e2010', 'e2020'),
    })),
    { ...options, name: 'New checkout' }
  );
  const other = catalogFromEasUpdates(fixture, {
    ...options,
    channel: 'draft-pr-43',
    name: 'Search',
  });
  const merged = mergeCatalogs(mergeCatalogs(other, newer), older);
  assert.equal(merged.drafts.length, 2);
  assert.equal(merged.drafts[0].name, 'New checkout');
  assert.equal(merged.drafts[1].channel, 'draft-pr-43');
  assert.equal(mergeCatalogs(merged, older, { maxDrafts: 1 }).drafts.length, 1);
  assert.throws(
    () => mergeCatalogs(merged, { ...older, projectId: fixture[0].group }),
    /different EAS projects/
  );
  assert.throws(() => mergeCatalogs(merged, older, { maxDrafts: 0 }), /positive integer/);
  assert.throws(() => validateCatalog({ ...merged, schemaVersion: 2 }), /schemaVersion/);
});

test('CLI accepts real JSON from a file, merges in-place, and does not modify output after invalid input', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'expo-drafts-cli-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const input = join(dir, 'updates.json');
  const output = join(dir, 'catalog.json');
  await writeFile(input, JSON.stringify(fixture));
  const args = [
    cli,
    'catalog',
    '--input',
    input,
    '--output',
    output,
    '--project-id',
    projectId,
    '--channel',
    options.channel,
    '--name',
    options.name,
    '--merge',
    output,
  ];
  execFileSync(process.execPath, args, { stdio: 'pipe' });
  execFileSync(process.execPath, args, { stdio: 'pipe' });
  const valid = await readFile(output, 'utf8');
  assert.equal(JSON.parse(valid).drafts.length, 1);
  await writeFile(input, '{}');
  assert.throws(() => execFileSync(process.execPath, args, { stdio: 'pipe' }), /nonempty/);
  assert.equal(await readFile(output, 'utf8'), valid);
});

test('concurrent catalog publishers retain every PR without changing the working checkout', async (t) => {
  const dir = await mkdtemp(join(tmpdir(), 'expo-drafts-git-test-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const remote = join(dir, 'remote.git');
  execFileSync('git', ['init', '--bare', remote], { stdio: 'pipe' });
  const run = promisify(execFile);
  const jobs = await Promise.all(
    Array.from({ length: 4 }, async (_, i) => {
      const repo = join(dir, `clone-${i}`);
      execFileSync('git', ['clone', remote, repo], { stdio: 'pipe' });
      const input = join(dir, `draft-${i}.json`);
      await writeFile(
        input,
        JSON.stringify(
          catalogFromEasUpdates(fixture, {
            ...options,
            channel: `draft-pr-${i + 1}`,
            name: `PR ${i + 1}`,
          })
        )
      );
      return { repo, input };
    })
  );
  await Promise.all(
    jobs.map(({ repo, input }) =>
      run(process.execPath, [publisher, '--input', input, '--repository', repo])
    )
  );
  const result = JSON.parse(
    execFileSync('git', ['--git-dir', remote, 'show', 'drafts-catalog:catalog.json'], {
      encoding: 'utf8',
    })
  );
  assert.deepEqual(result.drafts.map((entry) => entry.channel).sort(), [
    'draft-pr-1',
    'draft-pr-2',
    'draft-pr-3',
    'draft-pr-4',
  ]);
  for (const { repo } of jobs) {
    assert.equal(
      execFileSync('git', ['status', '--porcelain'], { cwd: repo, encoding: 'utf8' }),
      ''
    );
  }
});
