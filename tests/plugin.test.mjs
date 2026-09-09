import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { withExpoDrafts } = require('../app.plugin.js');
const id = 'e8ecb8b1-95ac-4f76-965a-df4b39ea3929';
const options = { projectId: id, catalogUrl: 'https://example.com/catalog.json' };

test('direct EAS discovery configures a project-specific login callback without a catalog endpoint', async () => {
  const result = withExpoDrafts({ name: 'test', slug: 'test' }, { projectId: id });
  assert.equal(result.updates.url, `https://u.expo.dev/${id}`);
  assert.deepEqual(result.runtimeVersion, { policy: 'fingerprint' });
  assert.equal(result.updates.requestHeaders['expo-channel-name'], 'drafts');
  const initialTypes = [{ CFBundleURLSchemes: ['existing-app'] }];
  const configured = await result.mods.ios.infoPlist({
    ...result,
    modResults: { CFBundleURLTypes: initialTypes },
    modRequest: { platform: 'ios', modName: 'infoPlist' },
  });
  const plist = configured.modResults;
  assert.equal(plist.ExpoDraftsCatalogURL, '');
  assert.equal(plist.ExpoDraftsBuildsCatalogURL, '');
  assert.equal(plist.ExpoDraftsAuthScheme, `expo-drafts.${id}`);
  assert.deepEqual(plist.CFBundleURLTypes[0], initialTypes[0]);
  assert.deepEqual(plist.CFBundleURLTypes[1].CFBundleURLSchemes, [`expo-drafts.${id}`]);
  const repeated = await result.mods.ios.infoPlist({ ...configured });
  assert.equal(repeated.modResults.CFBundleURLTypes.length, 2);
});

test('configures manual channel selection with fingerprint compatibility and recovery intact', () => {
  const result = withExpoDrafts(
    { name: 'test', slug: 'test', updates: { requestHeaders: { 'x-custom': 'retained' } } },
    options
  );
  assert.deepEqual(result.runtimeVersion, { policy: 'fingerprint' });
  assert.equal(result.updates.url, `https://u.expo.dev/${id}`);
  assert.equal(result.updates.checkAutomatically, 'NEVER');
  assert.deepEqual(result.updates.requestHeaders, {
    'x-custom': 'retained',
    'expo-channel-name': 'drafts',
    'expo-drafts-selection': 'embedded',
  });
  assert.notEqual(result.updates.disableAntiBrickingMeasures, true);
});

test('preserves explicit runtime and initial channel', () => {
  const result = withExpoDrafts(
    {
      name: 'test',
      slug: 'test',
      runtimeVersion: 'native-v2',
      updates: { requestHeaders: { 'expo-channel-name': 'internal' } },
    },
    options
  );
  assert.equal(result.runtimeVersion, 'native-v2');
  assert.equal(result.updates.requestHeaders['expo-channel-name'], 'internal');
});

test('prevents cross-project update configuration and disabled recovery', () => {
  assert.throws(
    () => withExpoDrafts({ updates: { url: 'https://u.expo.dev/another' } }, options),
    /must match/
  );
  assert.throws(
    () => withExpoDrafts({ updates: { disableAntiBrickingMeasures: true } }, options),
    /recovery/
  );
});

test('rejects invalid identities and insecure catalog endpoints', () => {
  for (const catalogUrl of [
    'http://example.com',
    'file:///tmp/catalog',
    'https://user:password@example.com',
  ]) {
    assert.throws(() => withExpoDrafts({}, { ...options, catalogUrl }), /HTTPS URL/);
  }
  assert.throws(() => withExpoDrafts({}, { ...options, projectId: 'invalid' }), /projectId/);
});

test('disabled production integration needs no catalog and leaves update behavior intact', () => {
  const config = { updates: { url: `https://u.expo.dev/${id}`, checkAutomatically: 'ON_LOAD' } };
  const result = withExpoDrafts(config, { enabled: false });
  assert.equal(result.updates.checkAutomatically, 'ON_LOAD');
  assert.equal(result.runtimeVersion, undefined);
});

test('build requests use GitHub authentication and reject arbitrary request endpoints', () => {
  assert.doesNotThrow(() => withExpoDrafts({}, {
    ...options,
    buildsCatalogUrl: 'https://example.com/build-catalog.json',
    buildRequestUrl: 'https://github.com/owner/repo/issues/new',
    buildProfile: 'drafts-device',
  }));
  for (const buildRequestUrl of [
    'https://example.com/request',
    'https://github.com/owner/repo/issues/new?body=changed',
    'https://github.com/owner/repo/issues/new#changed',
    'https://github.com:8443/owner/repo/issues/new',
    'https://github.com/owner/repo/actions',
  ]) {
    assert.throws(() => withExpoDrafts({}, { ...options, buildRequestUrl }), /buildRequestUrl/);
  }
  assert.throws(() => withExpoDrafts({}, { ...options, buildsCatalogUrl: 'http://example.com/builds' }), /HTTPS/);
  assert.throws(() => withExpoDrafts({}, { ...options, buildProfile: '../production' }), /buildProfile/);
});
