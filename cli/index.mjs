#!/usr/bin/env node
import { randomUUID } from 'node:crypto';
import { readFile, rename, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { parseArgs } from 'node:util';

import { catalogFromEasUpdates, mergeCatalogs } from './catalog.mjs';

const help = `expo-drafts catalog --input updates.json --output catalog.json \\
  --project-id UUID --channel draft-pr-42 --name "Improve checkout"

Commands:
  catalog  Convert EAS Update JSON into a catalog entry, optionally merge it.
  merge    Merge a catalog with --merge existing.json, keeping newest per channel.

Options:
  --input FILE        EAS JSON for catalog, catalog JSON for merge. Use - for stdin.
  --output FILE       Output path, or - for stdout. Default: -.
  --project-id UUID   EAS project ID. Required for catalog.
  --channel NAME      EAS channel that serves this draft. Required for catalog.
  --name TEXT         Human-readable draft title. Required for catalog.
  --merge FILE        Existing catalog. A missing file starts an empty catalog.
  --build-url URL     HTTPS link to the EAS build or builds page.
  --pr-number NUMBER  Pull request number. Requires --pr-url.
  --pr-url URL        HTTPS pull request URL. Requires --pr-number.
  --max-drafts NUMBER Maximum channels to retain. Default: 100.
  --help              Show this help.

Publish: eas update --channel draft-pr-42 --message "Improve checkout" \\
  --environment preview --non-interactive --json > updates.json
Import:  eas update:view GROUP_ID --json > updates.json
`;

async function readJson(path, allowMissing = false) {
  try {
    const text =
      path === '-'
        ? await new Promise((resolve, reject) => {
            let text = '';
            process.stdin.setEncoding('utf8');
            process.stdin.on('data', (chunk) => {
              text += chunk;
            });
            process.stdin.on('end', () => resolve(text));
            process.stdin.on('error', reject);
          })
        : await readFile(path, 'utf8');
    return JSON.parse(text);
  } catch (error) {
    if (allowMissing && error.code === 'ENOENT') return null;
    throw new Error(`Cannot read JSON from ${path}: ${error.message}`);
  }
}

async function main() {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: Object.fromEntries(
      [
        'input',
        'output',
        'project-id',
        'channel',
        'name',
        'merge',
        'build-url',
        'pr-number',
        'pr-url',
        'max-drafts',
      ]
        .map((name) => [name, { type: 'string' }])
        .concat([['help', { type: 'boolean' }]])
    ),
  });
  if (values.help || positionals.length === 0) {
    process.stdout.write(help);
    return;
  }
  const command = positionals[0];
  if (positionals.length !== 1 || !['catalog', 'merge'].includes(command)) {
    throw new Error('Expected catalog or merge. Use --help for usage.');
  }
  if (!values.input) throw new Error('--input is required.');
  if (values.input === '-' && values.merge === '-') {
    throw new Error('--input and --merge cannot both read stdin.');
  }
  if (Boolean(values['pr-number']) !== Boolean(values['pr-url'])) {
    throw new Error('--pr-number and --pr-url must be supplied together.');
  }
  const input = await readJson(values.input);
  const incoming =
    command === 'catalog'
      ? catalogFromEasUpdates(input, {
          projectId: values['project-id'],
          channel: values.channel,
          name: values.name,
          buildUrl: values['build-url'],
          pullRequest: values['pr-number']
            ? {
                number: Number(values['pr-number']),
                url: values['pr-url'],
              }
            : undefined,
        })
      : input;
  const existing = values.merge ? await readJson(values.merge, true) : null;
  const catalog = mergeCatalogs(existing, incoming, {
    maxDrafts: values['max-drafts'] ? Number(values['max-drafts']) : undefined,
  });
  const json = `${JSON.stringify(catalog, null, 2)}\n`;
  if (!values.output || values.output === '-') {
    process.stdout.write(json);
  } else {
    const output = resolve(values.output);
    await mkdir(dirname(output), { recursive: true });
    const temporary = `${output}.${randomUUID()}.tmp`;
    await writeFile(temporary, json);
    await rename(temporary, output);
    process.stderr.write(`Saved ${catalog.drafts.length} draft(s) to ${values.output}.\n`);
  }
}

main().catch((error) => {
  process.stderr.write(`expo-drafts: ${error.message}\n`);
  process.exitCode = 1;
});
