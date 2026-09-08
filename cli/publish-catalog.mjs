#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';
import { setTimeout } from 'node:timers/promises';

import { mergeCatalogs, validateCatalog } from './catalog.mjs';

/** Publish with a normal Git push. Retry races by merging against the new head. */
export async function publishCatalog({
  input,
  repository = '.',
  remote = 'origin',
  branch = 'drafts-catalog',
  attempts = 8,
}) {
  const incoming = validateCatalog(input);
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(branch)) {
    throw new Error('Catalog branch must contain only letters, numbers, underscores, or hyphens.');
  }
  if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(remote)) throw new Error('Invalid Git remote name.');
  if (!Number.isSafeInteger(attempts) || attempts < 1) throw new Error('Invalid retry count.');
  const scratch = await mkdtemp(join(tmpdir(), 'expo-drafts-catalog-'));
  const env = {
    ...process.env,
    GIT_INDEX_FILE: join(scratch, 'index'),
    GIT_AUTHOR_NAME: 'github-actions[bot]',
    GIT_AUTHOR_EMAIL: '41898282+github-actions[bot]@users.noreply.github.com',
    GIT_COMMITTER_NAME: 'github-actions[bot]',
    GIT_COMMITTER_EMAIL: '41898282+github-actions[bot]@users.noreply.github.com',
  };
  const git = (args, input) => {
    const result = spawnSync('git', args, { cwd: repository, env, input, encoding: 'utf8' });
    if (result.error) throw result.error;
    if (result.status !== 0) {
      const error = new Error(`git ${args[0]} failed: ${result.stderr.trim()}`);
      error.status = result.status;
      throw error;
    }
    return result.stdout.trim();
  };
  const ref = `refs/heads/${branch}`;
  try {
    for (let attempt = 0; attempt < attempts; attempt++) {
      let parent = null;
      try {
        git(['ls-remote', '--exit-code', '--heads', remote, ref]);
        git(['fetch', '--no-tags', remote, ref]);
        parent = git(['rev-parse', 'FETCH_HEAD']);
      } catch (error) {
        if (error.status !== 2) throw error; // ls-remote returns 2 for an absent ref.
      }
      const existing = parent ? JSON.parse(git(['show', `${parent}:catalog.json`])) : null;
      const catalog = mergeCatalogs(existing, incoming);
      git(parent ? ['read-tree', parent] : ['read-tree', '--empty']);
      const blob = git(['hash-object', '-w', '--stdin'], `${JSON.stringify(catalog, null, 2)}\n`);
      git(['update-index', '--add', '--cacheinfo', `100644,${blob},catalog.json`]);
      const tree = git(['write-tree']);
      const commit = git(
        ['commit-tree', tree, ...(parent ? ['-p', parent] : [])],
        'updates draft catalog\n'
      );
      try {
        git(['push', remote, `${commit}:${ref}`]);
        return { commit, count: catalog.drafts.length };
      } catch (error) {
        if (attempt === attempts - 1) throw error;
        // Other PRs can publish concurrently. Fetch their changes before retrying.
        await setTimeout(250 * (attempt + 1) + Math.random() * 250);
      }
    }
  } finally {
    await rm(scratch, { recursive: true, force: true });
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const { values } = parseArgs({
      options: {
        input: { type: 'string' },
        repository: { type: 'string' },
        remote: { type: 'string' },
        branch: { type: 'string' },
      },
    });
    if (!values.input) throw new Error('--input catalog.json is required.');
    const result = await publishCatalog({
      ...values,
      input: JSON.parse(await readFile(values.input, 'utf8')),
    });
    process.stdout.write(`Published ${result.count} draft(s) at ${result.commit}.\n`);
  } catch (error) {
    process.stderr.write(`expo-drafts: ${error.message}\n`);
    process.exitCode = 1;
  }
}
