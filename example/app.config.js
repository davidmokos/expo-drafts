module.exports = ({ config }) => ({
  ...config,
  // Native changes automatically produce a different compatible runtime.
  runtimeVersion: process.env.DRAFTS_TEST_RUNTIME || { policy: 'fingerprint' },
  plugins: [
    [
      '../app.plugin.js',
      {
        catalogUrl:
          'https://api.github.com/repos/davidmokos/expo-drafts/contents/catalog.json?ref=drafts-catalog',
        buildUrl: 'https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds',
        channel: 'drafts',
      },
    ],
  ],
});
