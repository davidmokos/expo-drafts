const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function object(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${label} must be an object.`);
  }
  return value;
}

function string(value, label) {
  if (typeof value !== 'string' || !value.trim()) {
    throw new Error(`${label} must be a nonempty string.`);
  }
  return value;
}

function uuid(value, label) {
  if (!UUID.test(string(value, label))) throw new Error(`${label} must be a UUID.`);
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
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password) {
    throw new Error(`${label} must be an HTTPS URL without credentials.`);
  }
  return parsed.href;
}

function optionalString(value, label) {
  return value === undefined || value === null ? undefined : string(value, label);
}

function platformUpdate(value, fallbackGroupId) {
  const update = object(value, 'Update');
  if (update.platform !== 'ios' && update.platform !== 'android') {
    throw new Error('Update platform must be ios or android.');
  }
  return {
    id: uuid(update.id, 'Update id'),
    groupId: uuid(update.groupId ?? fallbackGroupId, 'Update groupId'),
    platform: update.platform,
    runtimeVersion: string(update.runtimeVersion, 'Update runtimeVersion'),
  };
}

function draft(value) {
  const entry = object(value, 'Draft');
  const id = uuid(entry.id, 'Draft id');
  if (!Array.isArray(entry.updates) || entry.updates.length === 0) {
    throw new Error('Draft updates must be a nonempty array.');
  }
  const updates = entry.updates.map((update) => platformUpdate(update, id));
  if (new Set(updates.map((update) => update.platform)).size !== updates.length) {
    throw new Error('A draft can contain only one update per platform.');
  }
  let pullRequest;
  if (entry.pullRequest !== undefined) {
    object(entry.pullRequest, 'Draft pullRequest');
    if (!Number.isSafeInteger(entry.pullRequest.number) || entry.pullRequest.number < 1) {
      throw new Error('Pull request number must be a positive integer.');
    }
    pullRequest = {
      number: entry.pullRequest.number,
      url: httpsUrl(entry.pullRequest.url, 'Pull request URL'),
    };
  }
  return {
    id,
    name: string(entry.name, 'Draft name'),
    channel: string(entry.channel, 'Draft channel'),
    branch: optionalString(entry.branch, 'Draft branch'),
    message: optionalString(entry.message, 'Draft message'),
    createdAt: date(entry.createdAt, 'Draft createdAt'),
    gitCommitHash: optionalString(entry.gitCommitHash, 'Draft gitCommitHash'),
    pullRequest,
    buildUrl: entry.buildUrl === undefined ? undefined : httpsUrl(entry.buildUrl, 'Draft buildUrl'),
    updates: updates.sort((a, b) => a.platform.localeCompare(b.platform)),
  };
}

export function validateCatalog(value) {
  const catalog = object(value, 'Catalog');
  if (catalog.schemaVersion !== 1)
    throw new Error('Unsupported catalog schemaVersion. Expected 1.');
  if (!Array.isArray(catalog.drafts)) throw new Error('Catalog drafts must be an array.');
  return {
    schemaVersion: 1,
    projectId: uuid(catalog.projectId, 'Catalog projectId'),
    generatedAt: date(catalog.generatedAt, 'Catalog generatedAt'),
    drafts: catalog.drafts.map(draft),
  };
}

/** Convert one `eas update --json` or `eas update:view ID --json` response. */
export function catalogFromEasUpdates(input, options) {
  const updates = Array.isArray(input) ? input : input?.updates;
  if (!Array.isArray(updates) || updates.length === 0) {
    throw new Error(
      'Expected a nonempty EAS update JSON array or an object with an updates array.'
    );
  }
  for (const update of updates) {
    object(update, 'EAS update');
    if (update.isRollBackToEmbedded) {
      throw new Error('Rollback directives cannot be published as drafts. Publish an app update.');
    }
    uuid(update.group, 'EAS update group');
    date(update.createdAt, 'EAS update createdAt');
  }
  const branches = new Set(updates.map((update) => string(update.branch, 'EAS update branch')));
  if (branches.size !== 1)
    throw new Error('Input must contain a single publication on one branch.');
  const commits = new Set(updates.map((update) => update.gitCommitHash).filter(Boolean));
  if (commits.size > 1) throw new Error('Input contains updates from different commits.');

  // Fingerprint runtimes can differ by platform. EAS publishes separate group IDs
  // in that case, but all records in this command response form one draft.
  const latest = [...updates].sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt))[0];
  const id = updates.map((update) => update.group.toLowerCase()).sort()[0];
  return validateCatalog({
    schemaVersion: 1,
    projectId: options.projectId,
    generatedAt: options.now ?? new Date().toISOString(),
    drafts: [
      {
        id,
        name: options.name,
        channel: options.channel,
        branch: latest.branch,
        message: latest.message || undefined,
        createdAt: latest.createdAt,
        gitCommitHash: latest.gitCommitHash || undefined,
        pullRequest: options.pullRequest,
        buildUrl: options.buildUrl,
        updates: updates.map((update) => ({ ...update, groupId: update.group })),
      },
    ],
  });
}

/** Keep the newest publication per channel, including when jobs finish out of order. */
export function mergeCatalogs(existing, incoming, options = {}) {
  const next = validateCatalog(incoming);
  const previous = existing == null ? null : validateCatalog(existing);
  if (previous && previous.projectId !== next.projectId) {
    throw new Error('Cannot merge catalogs from different EAS projects.');
  }
  const maxDrafts = options.maxDrafts ?? 100;
  if (!Number.isSafeInteger(maxDrafts) || maxDrafts < 1) {
    throw new Error('maxDrafts must be a positive integer.');
  }
  const channels = new Map();
  for (const entry of [...(previous?.drafts ?? []), ...next.drafts]) {
    const current = channels.get(entry.channel);
    if (
      !current ||
      entry.createdAt > current.createdAt ||
      (entry.createdAt === current.createdAt && entry.id >= current.id)
    ) {
      channels.set(entry.channel, entry);
    }
  }
  return {
    schemaVersion: 1,
    projectId: next.projectId,
    generatedAt: date(options.now ?? new Date().toISOString(), 'Catalog generatedAt'),
    drafts: [...channels.values()]
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt) || a.channel.localeCompare(b.channel))
      .slice(0, maxDrafts),
  };
}
