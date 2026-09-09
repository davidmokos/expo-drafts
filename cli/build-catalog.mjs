#!/usr/bin/env node
import { readFile, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SHA = /^[0-9a-f]{40}$/i;
const PROFILE = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/;
const STATES = new Set(['queued', 'building', 'ready', 'failed']);
const RANK = { queued: 0, building: 1, failed: 2, ready: 3 };

function object(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value;
}

function string(value, label) {
  if (
    typeof value !== 'string' ||
    !value.trim() ||
    value !== value.trim() ||
    /[\x00-\x1f\x7f]/.test(value)
  ) {
    throw new Error(`${label} must be a nonempty string without control characters.`);
  }
  return value;
}

function uuid(value, label) {
  if (!UUID.test(string(value, label))) throw new Error(`${label} must be a UUID.`);
  return value.toLowerCase();
}

function commit(value, label = 'gitCommitHash') {
  if (!SHA.test(string(value, label))) throw new Error(`${label} must be a full Git commit hash.`);
  return value.toLowerCase();
}

function date(value, label) {
  if (typeof value !== 'string' || !Number.isFinite(Date.parse(value))) {
    throw new Error(`${label} must be a date string.`);
  }
  return new Date(value).toISOString();
}

function httpsUrl(value, label) {
  const parsed = new URL(string(value, label));
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || parsed.port) {
    throw new Error(`${label} must be an HTTPS URL without credentials or a custom port.`);
  }
  return parsed;
}

function githubUrl(value, label) {
  if (value === undefined) return undefined;
  const url = httpsUrl(value, label);
  if (
    url.hostname !== 'github.com' ||
    url.search ||
    url.hash ||
    !/^\/[\w.-]+\/[\w.-]+\/(?:issues\/[1-9]\d*|actions\/runs\/[1-9]\d*(?:\/attempts\/[1-9]\d*)?|actions\/workflows\/[\w.-]+\.ya?ml)$/.test(
      url.pathname
    )
  ) {
    throw new Error(`${label} must link to a GitHub issue, workflow, or Actions run.`);
  }
  return url.href;
}

function installUrl(value, buildId) {
  const url = httpsUrl(value, 'installUrl');
  const match = /^\/accounts\/[\w.-]+\/projects\/[\w.-]+\/builds\/([0-9a-f-]+)$/i.exec(
    url.pathname
  );
  if (
    url.hostname !== 'expo.dev' ||
    url.search ||
    url.hash ||
    !match ||
    match[1].toLowerCase() !== buildId
  ) {
    throw new Error('installUrl must be the expo.dev build page for this buildId.');
  }
  return url.href;
}

function identity(value) {
  const platform = value.platform ?? 'ios';
  const profile = value.profile ?? 'drafts-device';
  if (platform !== 'ios') throw new Error('Build platform must be ios.');
  if (typeof profile !== 'string' || !PROFILE.test(profile))
    throw new Error('Build profile must be a valid profile name.');
  const runtimeVersion = string(value.runtimeVersion, 'runtimeVersion');
  if (runtimeVersion.length > 256) throw new Error('runtimeVersion is too long.');
  return { platform, profile, runtimeVersion };
}

export function buildKey(value) {
  const { platform, profile, runtimeVersion } = identity(value);
  return JSON.stringify([platform, profile, runtimeVersion]);
}

function validateRecord(value) {
  const entry = object(value, 'Build record');
  if (
    entry.platform !== 'ios' ||
    typeof entry.profile !== 'string' ||
    !PROFILE.test(entry.profile)
  ) {
    throw new Error('Build records require platform ios and a valid profile.');
  }
  const key = identity(entry);
  if (!STATES.has(entry.state)) throw new Error('Unknown build state.');
  const requestId = string(entry.requestId, 'requestId');
  if (!/^[\w][\w.:-]{0,127}$/.test(requestId)) throw new Error('Invalid requestId.');
  const requestedAt = date(entry.requestedAt, 'requestedAt');
  const updatedAt = date(entry.updatedAt, 'updatedAt');
  if (updatedAt < requestedAt) throw new Error('updatedAt cannot precede requestedAt.');
  const buildId = entry.buildId === undefined ? undefined : uuid(entry.buildId, 'buildId');
  if (entry.state === 'ready' && !buildId) throw new Error('A ready build requires buildId.');
  if (entry.state !== 'ready' && entry.installUrl !== undefined) {
    throw new Error('Only a ready build can have installUrl.');
  }
  return {
    ...key,
    state: entry.state,
    requestId,
    requestedAt,
    updatedAt,
    gitCommitHash: commit(entry.gitCommitHash),
    buildId,
    installUrl: entry.state === 'ready' ? installUrl(entry.installUrl, buildId) : undefined,
    requestUrl: githubUrl(entry.requestUrl, 'requestUrl'),
    statusUrl: githubUrl(entry.statusUrl, 'statusUrl'),
  };
}

export function validateBuildCatalog(value) {
  const catalog = object(value, 'Build catalog');
  if (catalog.schemaVersion !== 1) throw new Error('Unsupported build catalog schemaVersion.');
  if (!Array.isArray(catalog.builds)) throw new Error('Build catalog builds must be an array.');
  const builds = catalog.builds.map(validateRecord);
  if (new Set(builds.map(buildKey)).size !== builds.length) {
    throw new Error('Build catalog contains duplicate runtime/platform/profile keys.');
  }
  return {
    schemaVersion: 1,
    projectId: uuid(catalog.projectId, 'projectId'),
    generatedAt: date(catalog.generatedAt, 'generatedAt'),
    builds,
  };
}

/** Trusted workflow state. A request cannot manufacture an installable build. */
export function createBuildRequestRecord(options) {
  if (!['queued', 'building', 'failed'].includes(options.state)) {
    throw new Error(
      'Request state must be queued, building, or failed; ready requires EAS metadata.'
    );
  }
  return validateRecord({
    ...options,
    ...identity(options),
    gitCommitHash: options.gitCommitHash ?? options.gitCommit,
    updatedAt: options.updatedAt ?? options.now ?? new Date().toISOString(),
  });
}

function wrap(record, options) {
  return validateBuildCatalog({
    schemaVersion: 1,
    projectId: options.projectId,
    generatedAt: options.now ?? new Date().toISOString(),
    builds: [record],
  });
}

export function buildCatalogFromRequest(options) {
  return wrap(createBuildRequestRecord(options), options);
}

/** Accept current and older `eas build:view ID --json` shapes, failing closed. */
export function buildCatalogFromEasBuild(input, options) {
  const build = object(input, 'EAS build');
  const expected = identity(options);
  const expectedProjectId = uuid(options.projectId, 'projectId');
  const buildId = uuid(build.id, 'EAS build id');
  if (
    options.expectedBuildId !== undefined &&
    buildId !== uuid(options.expectedBuildId, 'expectedBuildId')
  ) {
    throw new Error('EAS metadata does not match the expected build ID.');
  }
  const apps = [build.app, build.project].filter((value) => value != null);
  if (!apps.length) throw new Error('EAS build has no project identity.');
  for (const app of apps) {
    if (uuid(object(app, 'EAS build project').id, 'EAS project id') !== expectedProjectId) {
      throw new Error('EAS build belongs to a different project.');
    }
  }
  const runtimes = [build.runtime?.version, build.runtimeVersion].filter((value) => value != null);
  if (!runtimes.length || runtimes.some((runtime) => runtime !== expected.runtimeVersion)) {
    throw new Error('EAS build runtime is unknown or does not match the requested runtimeVersion.');
  }
  if (build.platform !== 'IOS') throw new Error('EAS build platform must be IOS.');
  if (build.buildProfile !== expected.profile)
    throw new Error('EAS build profile does not match the requested profile.');
  if (build.distribution !== 'INTERNAL')
    throw new Error('EAS build distribution must be INTERNAL.');
  if (build.isForIosSimulator !== false)
    throw new Error('EAS build must explicitly be a physical device build, not a simulator build.');
  if (build.developmentClient === true)
    throw new Error('An EAS development client is not an installable Release preview.');
  if (build.status !== 'FINISHED')
    throw new Error('EAS build must be FINISHED before it is ready.');
  httpsUrl(build.artifacts?.applicationArchiveUrl, 'EAS applicationArchiveUrl');
  const now = date(options.now ?? new Date().toISOString(), 'now');
  date(build.completedAt, 'EAS completedAt');
  if (build.expirationDate != null && date(build.expirationDate, 'EAS expirationDate') <= now) {
    throw new Error('EAS build artifact has expired.');
  }
  const gitCommitHash = commit(build.gitCommitHash, 'EAS gitCommitHash');
  if (
    options.expectedBuildCommit !== undefined &&
    gitCommitHash !== commit(options.expectedBuildCommit)
  ) {
    throw new Error('EAS build commit does not match the expected build commit.');
  }
  const app = apps[0];
  const owner = string(app.ownerAccount?.name, 'EAS ownerAccount.name');
  const slug = string(app.slug, 'EAS project slug');
  if (apps.some((candidate) => candidate.ownerAccount?.name !== owner || candidate.slug !== slug)) {
    throw new Error('EAS app and project metadata disagree.');
  }
  if (![owner, slug].every((part) => /^[\w.-]+$/.test(part) && part !== '.' && part !== '..')) {
    throw new Error('EAS account name or project slug is invalid.');
  }
  return wrap(
    validateRecord({
      ...options,
      ...expected,
      state: 'ready',
      buildId,
      gitCommitHash,
      updatedAt: options.updatedAt ?? now,
      installUrl: `https://expo.dev/accounts/${owner}/projects/${slug}/builds/${buildId}`,
    }),
    { ...options, now }
  );
}

function chooseRecord(current, incoming) {
  if (!current) return incoming;
  if (current.requestId === incoming.requestId) {
    if (current.requestedAt !== incoming.requestedAt)
      throw new Error('One requestId cannot have different requestedAt values.');
    if (current.buildId && incoming.buildId && current.buildId !== incoming.buildId) {
      throw new Error('One requestId cannot identify different EAS builds.');
    }
  }
  // A finished, installable build stays useful even if a duplicate request fails.
  if ((current.state === 'ready') !== (incoming.state === 'ready')) {
    return current.state === 'ready' ? current : incoming;
  }
  if (current.requestId === incoming.requestId) {
    if (RANK[current.state] !== RANK[incoming.state]) {
      return RANK[incoming.state] > RANK[current.state] ? incoming : current;
    }
  } else if (current.requestedAt !== incoming.requestedAt) {
    return incoming.requestedAt > current.requestedAt ? incoming : current;
  } else if (current.requestId !== incoming.requestId) {
    return incoming.requestId > current.requestId ? incoming : current;
  }
  if (current.updatedAt !== incoming.updatedAt)
    return incoming.updatedAt > current.updatedAt ? incoming : current;
  return JSON.stringify(incoming) > JSON.stringify(current) ? incoming : current;
}

/** Latest request wins, with monotonic states per request and a durable ready build. */
export function mergeBuildCatalogs(existing, incoming, options = {}) {
  const next = validateBuildCatalog(incoming);
  const previous = existing == null ? null : validateBuildCatalog(existing);
  if (previous && previous.projectId !== next.projectId)
    throw new Error('Cannot merge builds from different EAS projects.');
  const builds = new Map();
  for (const entry of [...(previous?.builds ?? []), ...next.builds]) {
    const key = buildKey(entry);
    builds.set(key, chooseRecord(builds.get(key), entry));
  }
  return {
    schemaVersion: 1,
    projectId: next.projectId,
    generatedAt: date(options.now ?? new Date().toISOString(), 'generatedAt'),
    builds: [...builds.values()].sort(
      (a, b) => b.updatedAt.localeCompare(a.updatedAt) || buildKey(a).localeCompare(buildKey(b))
    ),
  };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    const { values, positionals } = parseArgs({
      allowPositionals: true,
      options: Object.fromEntries(
        [
          'input',
          'output',
          'project-id',
          'runtime-version',
          'platform',
          'profile',
          'git-commit',
          'request-id',
          'requested-at',
          'state',
          'request-url',
          'status-url',
          'build-id',
          'updated-at',
          'expected-build-commit',
          'expected-build-id',
        ].map((name) => [name, { type: 'string' }])
      ),
    });
    if (
      positionals.length !== 1 ||
      !['request', 'build'].includes(positionals[0]) ||
      !values.output
    ) {
      throw new Error(
        'Use request|build --output entry.json with project, runtime, and request identity flags.'
      );
    }
    const options = Object.fromEntries(
      Object.entries(values).map(([key, value]) => [
        key.replace(/-([a-z])/g, (_, letter) => letter.toUpperCase()),
        value,
      ])
    );
    const catalog =
      positionals[0] === 'request'
        ? buildCatalogFromRequest(options)
        : buildCatalogFromEasBuild(JSON.parse(await readFile(values.input, 'utf8')), options);
    await writeFile(values.output, `${JSON.stringify(catalog, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`expo-drafts: ${error.message}\n`);
    process.exitCode = 1;
  }
}
