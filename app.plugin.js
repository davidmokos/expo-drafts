const {
  withInfoPlist,
  withAndroidManifest,
  AndroidConfig,
  createRunOncePlugin,
} = require('expo/config-plugins');

function httpsURL(value, name) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`expo-drafts: ${name} must be an HTTPS URL.`);
  }
  if (url.protocol !== 'https:' || url.username || url.password) {
    throw new Error(`expo-drafts: ${name} must be an HTTPS URL without credentials.`);
  }
  return url.toString();
}

function withExpoDrafts(config, options = {}) {
  const enabled = options.enabled !== false;
  const projectId = options.projectId || config.extra?.eas?.projectId;
  let catalogUrl = '';
  let buildUrl = '';
  let buildsCatalogUrl = '';
  let buildRequestUrl = '';
  const buildProfile = options.buildProfile || 'drafts-device';
  if (enabled) {
    if (!/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(projectId || '')) {
      throw new Error('expo-drafts: provide projectId or run eas init first.');
    }
    catalogUrl = httpsURL(options.catalogUrl, 'catalogUrl');
    buildUrl = httpsURL(
      options.buildUrl || `https://expo.dev/projects/${projectId}/builds`,
      'buildUrl'
    );
    if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(buildProfile)) {
      throw new Error('expo-drafts: buildProfile must be an EAS build profile name.');
    }
    if (options.buildsCatalogUrl) {
      buildsCatalogUrl = httpsURL(options.buildsCatalogUrl, 'buildsCatalogUrl');
    }
    if (options.buildRequestUrl) {
      buildRequestUrl = httpsURL(options.buildRequestUrl, 'buildRequestUrl');
      const request = new URL(buildRequestUrl);
      if (request.hostname !== 'github.com' || request.port || request.search || request.hash ||
        !/^\/[a-zA-Z0-9_.-]+\/[a-zA-Z0-9_.-]+\/issues\/new$/.test(request.pathname)) {
        throw new Error('expo-drafts: buildRequestUrl must be https://github.com/OWNER/REPO/issues/new without query parameters.');
      }
    }
    const updateUrl = `https://u.expo.dev/${projectId}`;
    if (config.updates?.url && config.updates.url.replace(/\/$/, '') !== updateUrl) {
      throw new Error('expo-drafts: updates.url must match the configured EAS project.');
    }
    if (config.updates?.disableAntiBrickingMeasures) {
      throw new Error(
        'expo-drafts: remove disableAntiBrickingMeasures. Channel switching preserves update recovery.'
      );
    }
    config.runtimeVersion ??= { policy: 'fingerprint' };
    config.updates = {
      ...config.updates,
      enabled: true,
      url: updateUrl,
      checkAutomatically: 'NEVER',
      requestHeaders: {
        ...config.updates?.requestHeaders,
        'expo-channel-name':
          options.channel || config.updates?.requestHeaders?.['expo-channel-name'] || 'drafts',
        'expo-drafts-selection': 'embedded',
      },
    };
  }
  config = withInfoPlist(config, (mod) => {
    Object.assign(mod.modResults, {
      ExpoDraftsEnabled: enabled,
      ExpoDraftsProjectID: projectId || '',
      ExpoDraftsCatalogURL: catalogUrl,
      ExpoDraftsBuildURL: buildUrl,
      ExpoDraftsBuildsCatalogURL: buildsCatalogUrl,
      ExpoDraftsBuildRequestURL: buildRequestUrl,
      ExpoDraftsBuildProfile: buildProfile,
    });
    return mod;
  });
  return withAndroidManifest(config, (mod) => {
    const app = AndroidConfig.Manifest.getMainApplicationOrThrow(mod.modResults);
    for (const [key, value] of Object.entries({
      ENABLED: String(enabled),
      PROJECT_ID: projectId || '',
      CATALOG_URL: catalogUrl,
      BUILD_URL: buildUrl,
    })) {
      AndroidConfig.Manifest.addMetaDataItemToMainApplication(
        app,
        `expo.modules.drafts.${key}`,
        value
      );
    }
    return mod;
  });
}

module.exports = createRunOncePlugin(withExpoDrafts, 'expo-drafts', '0.1.0');
module.exports.withExpoDrafts = withExpoDrafts;
