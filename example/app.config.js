module.exports = ({ config }) => ({
  ...config,
  // Native changes automatically produce a different compatible runtime.
  runtimeVersion: process.env.DRAFTS_TEST_RUNTIME || { policy: 'fingerprint' },
  plugins: [
    [
      '../app.plugin.js',
      {
        catalogUrl:
          'https://raw.githubusercontent.com/davidmokos/expo-drafts/drafts-catalog/catalog.json',
        buildUrl: 'https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds',
        channel: 'drafts',
      },
    ],
  ],
});
