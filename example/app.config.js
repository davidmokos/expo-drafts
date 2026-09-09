module.exports = ({ config }) => ({
  ...config,
  // Native changes automatically produce a different compatible runtime.
  runtimeVersion: process.env.DRAFTS_TEST_RUNTIME || { policy: 'fingerprint' },
  plugins: [
    'expo-router',
    'expo-splash-screen',
    [
      '../app.plugin.js',
      {
        buildUrl: 'https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds',
        buildRequestUrl: 'https://github.com/davidmokos/expo-drafts/issues/new',
        buildProfile: 'drafts-device',
        channel: 'drafts',
      },
    ],
  ],
});
