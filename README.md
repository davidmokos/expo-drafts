# expo-drafts

A native draft picker for Expo apps. Publish a pull request to EAS Update, open the floating button, and run that PR in an installed preview build. No Metro server or `expo-dev-client` is required.

This version targets iOS. The picker runs in UIKit, outside the React bundle. Android source is included as unfinished work and is not registered for autolinking. It remains available across JavaScript reloads and when JavaScript stops responding.

## How drafts work

Each PR publishes to a channel such as `draft-pr-42`. The app shows the PR title, channel, commit, and latest publication. A catalog generated in CI contains the platform update IDs and runtime versions. Expo credentials stay in CI.

Only the latest publication on each channel is listed. Publishing again updates that entry. For separate named experiments, use distinct channels such as `draft-search-redesign` or `draft-checkout-agent-a`.

A draft can run only when its platform and `runtimeVersion` match the installed native build. Incompatible drafts stay visible with **Needs new EAS build** and a link to EAS builds. The plugin defaults to Expo's `fingerprint` runtime policy, so changes that affect native compatibility produce a different runtime.

Selecting a draft changes the native `expo-channel-name` header, downloads the update, verifies its exact ID, and reloads. This also supports switching back to an older update on another channel. If the channel changed after the catalog loaded, the picker restores the previous channel and asks you to refresh.

## Install

Version 0.1 targets iOS on Expo SDK 57 with `expo-updates` 57. It uses native update-controller APIs, so support for other SDK versions must be verified before widening the peer dependency range.

Use EAS CLI 23.2 or newer. Until an npm release is published:

```sh
npx expo install expo-updates
npm install github:davidmokos/expo-drafts
```

Run `eas init` in the app, then add the plugin:

```js
// app.config.js
export default {
  expo: {
    name: 'My app previews',
    slug: 'my-app',
    extra: { eas: { projectId: 'YOUR_EAS_PROJECT_UUID' } },
    plugins: [
      ['expo-drafts', {
        catalogUrl: 'https://raw.githubusercontent.com/OWNER/REPO/drafts-catalog/catalog.json',
        buildUrl: 'https://expo.dev/accounts/OWNER/projects/SLUG/builds',
        channel: 'drafts',
      }],
    ],
  },
};
```

The plugin configures EAS Update, an embedded channel header, manual update checks, and native picker settings. It preserves other custom request headers and refuses a mismatched EAS project or disabled update recovery.

Create an internal release build. A development build or Expo Go cannot load these updates:

```json
{
  "build": {
    "drafts": {
      "distribution": "internal",
      "channel": "drafts",
      "environment": "preview",
      "ios": { "simulator": true },
      "android": { "buildType": "apk" }
    }
  }
}
```

```sh
eas build --profile drafts --platform ios
# Or compile and install locally:
npx expo run:ios --configuration Release --no-bundler
```

The floating button appears automatically. No React provider, screen, or JavaScript initialization is required. To open it from your app:

```ts
import { openDrafts, setDraftsVisible, getDraftsState } from 'expo-drafts';

await openDrafts();
await setDraftsVisible(false);
const { runtimeVersion, updateId } = getDraftsState();
```

The button's visibility applies to the current process. Include the plugin with `{ enabled: false }` in production builds. Without the plugin's native enabled flag, the installed module does not display a picker.

## Publish from PRs

See [the workflow guide](docs/workflow.md) and [.github/workflows/drafts.yml](.github/workflows/drafts.yml). The workflow publishes same-repository PRs to `draft-pr-N`, then merges the catalog using Git push retries so parallel PRs do not overwrite each other. Fork PRs do not receive Expo credentials.

For a manual publication:

```sh
eas update --channel draft-search --message 'Search redesign' \
  --environment preview --non-interactive --json > eas-update.json

npx expo-drafts catalog \
  --input eas-update.json --output catalog.json \
  --project-id YOUR_EAS_PROJECT_UUID \
  --channel draft-search --name 'Search redesign'
```

Host `catalog.json` at the configured HTTPS URL. Pass `--merge catalog.json` to retain other channels. The catalog contains preview names, commit IDs, runtime versions, and update IDs. For private project metadata, serve it through your own access-controlled endpoint and add an authentication integration before use. The included GitHub raw catalog is public.

## Test app

`example/` is Drafts Lab, a new Expo app linked to `@mokosdavid/expo-drafts-lab`. Its native picker uses this repository's catalog. Set `EXPO_PUBLIC_DRAFT_VARIANT` to `amber` or `ocean` while publishing to produce distinct app screens.

```sh
npm ci
npm run build
npm ci --prefix example
cd example
npm run ios -- --device YOUR_SIMULATOR_UDID
```

`npm run ios` compiles a release app with a bundled fallback. The installed app does not need a running Metro process. Android build and simulator validation are deferred.

Run `npm test` for catalog and plugin validation, and `bash tests/ios/run.sh` for the iOS cache transaction tests. Native projects in the example are generated by Expo prebuild and are not committed.

## Recovery and limits

Channel switching keeps Expo's embedded fallback and anti-bricking measures enabled. This package does not override the update URL or disable those measures. A native process crash still ends the app; reopen it to allow Expo recovery and access the picker again. Recovery restores the previous channel. If Expo has already removed its cached update after a relaunch, the app may return to the embedded version.

The iOS cache adapter uses Expo SDK 57's `updates` and `json_data` schema through public `UpdatesDatabase` APIs. Review it when upgrading the SDK. The picker serializes its own switches; app code must not start another `expo-updates` download or reload during a switch.

The same app installation shares its local data across drafts. Keep database migrations and persisted state compatible across the PRs you switch between. The picker changes JavaScript and assets, not native code.

The build link opens EAS. It does not request a paid build automatically. Closed PR cleanup and access-controlled catalog authentication are not implemented in this first version.

The design follows Expo's [channel surfing](https://docs.expo.dev/eas-update/channel-surfing/), [runtime compatibility](https://docs.expo.dev/eas-update/runtime-versions/), and [error recovery](https://docs.expo.dev/eas-update/error-recovery/) behavior. Native implementation references were inspected in the local Expo repository.

MIT
