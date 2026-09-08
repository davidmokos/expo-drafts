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
  if (enabled) {
    if (!/^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$/i.test(projectId || '')) {
      throw new Error('expo-drafts: provide projectId or run eas init first.');
    }
    catalogUrl = httpsURL(options.catalogUrl, 'catalogUrl');
    buildUrl = httpsURL(
      options.buildUrl || `https://expo.dev/projects/${projectId}/builds`,
      'buildUrl'
    );
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
