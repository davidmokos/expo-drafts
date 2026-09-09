# expo-drafts

A native draft picker for Expo apps. Publish a pull request to EAS Update, open the floating button, and run that PR in an installed preview build. No Metro server or `expo-dev-client` is required.

This version targets iOS. The picker runs in UIKit, outside the React bundle, and remains available across JavaScript reloads and when JavaScript stops responding. Android source is included as unfinished work and is not registered for autolinking.

## How drafts work

Each PR publishes to a channel such as `draft-pr-42`. The picker shows the preview name and PR number, with a checkmark on the current update. Manually named previews show their channel as the subtitle. A catalog generated in CI contains the commit, platform update IDs, and runtime versions. Expo credentials stay in CI.

The picker uses standard UIKit inset grouped rows, search, a Done button, and pull to refresh. It follows the system's light or dark appearance. Its draggable floating button uses the system glass style on iOS 26 and later, with a tinted button on earlier versions.

Only the latest publication on each channel is listed. Publishing again updates that entry. For separate named experiments, use distinct channels such as `draft-search-redesign` or `draft-checkout-agent-a`.

A draft can run only when its platform and `runtimeVersion` match the installed native build. Incompatible drafts stay visible and open native build actions when tapped. The picker offers a verified compatible build, shows a queued or running build, or opens **Request Build** on GitHub. See [native build setup](docs/native-builds.md). The plugin defaults to Expo's `fingerprint` runtime policy, so changes that affect native compatibility produce a different runtime.

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
        catalogUrl: 'https://api.github.com/repos/OWNER/REPO/contents/catalog.json?ref=drafts-catalog',
        buildsCatalogUrl: 'https://api.github.com/repos/OWNER/REPO/contents/build-catalog.json?ref=drafts-catalog',
        buildRequestUrl: 'https://github.com/OWNER/REPO/issues/new',
        buildProfile: 'drafts-device',
        buildUrl: 'https://expo.dev/accounts/OWNER/projects/SLUG/builds',
        channel: 'drafts',
      }],
    ],
  },
};
```

The plugin configures EAS Update, an embedded channel header, manual update checks, and native picker settings. It preserves other custom request headers and refuses a mismatched EAS project or disabled update recovery.

Create an internal release build for expo-drafts. Its native picker requires Release mode and is unavailable in Expo Go:

```json
{
  "build": {
    "drafts": {
      "distribution": "internal",
      "channel": "drafts",
      "environment": "preview",
      "ios": { "simulator": true }
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

## Native builds from the picker

Tap an incompatible draft to see its native build actions. A finished build with the exact iOS runtime and configured device profile offers **Install compatible build**, which hands the build directly to iOS's installer without opening the EAS website. Confirm the system installation dialog, then reopen the app. Queued and running builds show progress. If no matching build exists, **Request Build** opens a prefilled GitHub issue; sign in and submit it to start the build workflow. The app refreshes build status when you return, on pull to refresh, and every 30 seconds while an incompatible build is in progress and the picker is visible.

Build requests require repository write access. Trusted GitHub Actions code validates the request against the current draft catalog and the PR's source commit before dispatching EAS Workflows. The EAS workflow reuses an existing matching internal device build, or creates one. Only a completed build with verified project, runtime, profile, and device distribution metadata gets an install link. Expo and Apple credentials remain in GitHub/EAS.

Your iPhone must be included in the build's ad hoc provisioning profile. Installation requires the system installation flow and replaces the app's native binary. Reopen the app afterward; only updates matching that build's runtime will be selectable. TestFlight is not required.

The build catalog and request URL are optional. Existing update selection works without them. See [native build setup](docs/native-builds.md) for signing, workflows, and integration in another repository.

## Publish from PRs

See [the workflow guide](docs/workflow.md), the [GitHub dispatcher](.github/workflows/drafts.yml), and the [EAS workflow](example/.eas/workflows/publish-draft.yml). Each same-repository PR uploads its exact source commit to EAS Workflows, which publishes the iOS update to `draft-pr-N`. GitHub then merges the catalog using Git push retries so parallel PRs do not overwrite each other. Fork PRs do not receive Expo credentials.

For a manual publication:

```sh
eas update --platform ios --channel draft-search --message 'Search redesign' \
  --environment preview --non-interactive --json > eas-update.json

npx expo-drafts catalog \
  --input eas-update.json --output catalog.json \
  --project-id YOUR_EAS_PROJECT_UUID \
  --channel draft-search --name 'Search redesign'
```

Host `catalog.json` at the configured HTTPS URL. Pass `--merge catalog.json` to retain other channels. The catalog contains preview names, commit IDs, runtime versions, and update IDs. For private project metadata, serve it through your own access-controlled endpoint and add an authentication integration before use. The included GitHub catalog is public. GitHub limits anonymous API requests per IP; use your own HTTPS endpoint for larger testing teams.

## Test app

`example/` is Drafts Lab, a new Expo app linked to `@mokosdavid/expo-drafts-lab`. Its native picker uses this repository's catalog. Set `EXPO_PUBLIC_DRAFT_VARIANT` to `amber` or `ocean` while publishing to produce distinct app screens.

Direct installation uses native runtime `166ee8786683217e3c8d06b3e8b322e68f80e17d`. PRs #1 through #4 have been republished through EAS Workflows for that runtime. PR #5 changes `ios.supportsTablet` to `false` and uses runtime `b585b87f336c7d3a807921c6c6e80795b9fdd2e0`, providing a real native upgrade to try from the picker. The original manual Amber, Ocean, and Camera entries remain in the catalog with earlier runtimes. See the [validation record](docs/ios-validation.md#direct-installation-from-the-app) for exact update IDs and completed checks.

```sh
npm ci
npm run build
npm ci --prefix example
cd example
npm run ios -- --device YOUR_SIMULATOR_UDID
```

`npm run ios` compiles a release app with a bundled fallback. The installed app does not need a running Metro process. Android build and simulator validation are deferred.

For a connected physical iPhone, you can compile and install locally from `example/` using a signing certificate and provisioning profile already configured in Xcode:

```sh
npm run ios -- --device "YOUR_IPHONE_NAME"
```

The script builds Release without Metro. If the existing profile is managed by Xcode, use Automatic signing on the app target in Xcode. See the [historical iPhone validation notes](docs/ios-validation.md#historical-physical-iphone-validation) for completed local installations of earlier native revisions.

For an EAS cloud build, register the device with EAS and build the `drafts-device` profile from `example/`:

```sh
eas device:create
eas build --profile drafts-device --platform ios
```

This creates a signed internal Release build. Install it from the EAS build page on a device included in its provisioning profile. The simulator and device profiles use the same native runtime, so both can select the same compatible PR updates. EAS installs the parent package through the example's build hook; see the [workflow guide](docs/workflow.md) for its fingerprint handling.

Run `npm test` for catalog, build request, workflow, and plugin validation. Run `bash tests/ios/run.sh` for the iOS cache transactions, exact build matching, installation URL checks, and native request URL round-trip through the CI parser. Native projects in the example are generated by Expo prebuild and are not committed.

See the [iOS validation record](docs/ios-validation.md) for simulator coverage and the published test updates.

## Recovery and limits

Channel switching keeps Expo's embedded fallback and anti-bricking measures enabled. This package does not override the update URL or disable those measures. A native process crash still ends the app; reopen it to allow Expo recovery and access the picker again. Recovery restores the previous channel. If Expo has already removed its cached update after a relaunch, the app may return to the embedded version.

The iOS cache adapter uses Expo SDK 57's `updates` and `json_data` schema through public `UpdatesDatabase` APIs. Review it when upgrading the SDK. The picker serializes its own switches; app code must not start another `expo-updates` download or reload during a switch.

The same app installation shares its local data across drafts. Keep database migrations and persisted state compatible across the PRs you switch between. Switching EAS Updates changes JavaScript and assets. Installing a compatible build replaces the native binary.

Creating a GitHub build request can consume EAS build minutes. Opening the request page alone starts no build. Closed PR cleanup and access-controlled catalog authentication are not implemented in this first version.

The design follows Expo's [channel surfing](https://docs.expo.dev/eas-update/channel-surfing/), [runtime compatibility](https://docs.expo.dev/eas-update/runtime-versions/), and [error recovery](https://docs.expo.dev/eas-update/error-recovery/) behavior. Native implementation references were inspected in the local Expo repository.

MIT
