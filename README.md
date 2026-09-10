# expo-drafts

A native draft picker for Expo apps. Publish a pull request to EAS Update, open the floating button, and run that PR in an installed preview build. No Metro server or `expo-dev-client` is required.

This version targets iOS. The picker runs in UIKit, outside the React bundle, and remains available across JavaScript reloads and when JavaScript stops responding. Android and web are unsupported. Unfinished Android source remains in the repository and is excluded from the npm package.

## How drafts work

Each PR publishes to an EAS channel such as `draft-pr-42`. Sign in to Expo in the native picker to browse updates and builds directly from EAS. Update messages provide the preview names, and channels identify separate drafts. The app reads exact update IDs, source commits, and native runtimes from EAS rather than a GitHub JSON index. Your Expo session is stored in the iOS Keychain; no publishing token is bundled with the app.

The picker uses standard UIKit inset grouped rows, search, a Done button, and pull to refresh. It follows the system's light or dark appearance. Its draggable floating button uses the system glass style on iOS 26 and later, with a tinted button on earlier versions.

Only the latest iOS publication on each channel is listed, newest first. Each row shows its publication date and time in the device's local format and time zone. Publishing again updates that entry and its position. For separate named experiments, use distinct channels such as `draft-search-redesign` or `draft-checkout-agent-a`.

A draft can run only when its platform and `runtimeVersion` match the installed native build. Incompatible drafts stay visible and open native build actions when tapped. The included PR workflow automatically reuses or creates a matching native build after publication. The picker offers a compatible build when ready and shows builds in progress; **Request Build** remains available as a manual fallback. See [native build setup](https://github.com/davidmokos/expo-drafts/blob/main/docs/native-builds.md). The plugin defaults to Expo's `fingerprint` runtime policy, so changes that affect native compatibility produce a different runtime.

When installing a compatible build from the picker, it remembers the exact selected update. Reopen the app after iOS finishes installation and that update opens automatically. Interrupted attempts, network errors, or a changed publication show a native retry/cancel action.

Selecting a draft changes the native `expo-channel-name` header, downloads the update, verifies its exact ID, and reloads. This also supports switching back to an older update on another channel. If the channel changed after the catalog loaded, the picker restores the previous channel and asks you to refresh.

## Install

Version 0.1 targets iOS on Expo SDK 57 with `expo-updates` 57. It uses native update-controller APIs, so support for other SDK versions must be verified before widening the peer dependency range.

Install the package in your Expo SDK 57 app:

```sh
npx expo install expo-drafts expo-updates
npx eas-cli@23.2.0 init
```

Use a separate internal **Release preview** profile with `developmentClient: false`. A normal Metro development build and Expo Go do not provide the update-controller behavior this picker needs. You can keep your usual `development` profile alongside it. See [Expo's update testing guidance](https://docs.expo.dev/versions/v57.0.0/sdk/updates/#testing).

Merge this into your app's config after linking its own EAS project:

```js
// app.config.js
export default ({ config }) => {
  const draftsEnabled = process.env.DRAFTS_ENABLED === '1';
  return {
    ...config,
    runtimeVersion: draftsEnabled
      ? { policy: 'fingerprint' }
      : config.runtimeVersion,
    plugins: [
      ...(config.plugins ?? []),
      ['expo-drafts', {
        enabled: draftsEnabled,
        channel: 'drafts',
        buildProfile: 'drafts-device',
        buildRequestUrl: 'https://github.com/OWNER/REPO/issues/new',
      }],
    ],
  };
};
```

`eas init` supplies `extra.eas.projectId`. Replace `OWNER/REPO` with your app's GitHub repository. The plugin sets the EAS Update URL, initial channel header, manual update checks, Expo sign-in callback, and native picker settings. Use `DRAFTS_ENABLED=1` only for iOS preview builds and updates; leave it unset for production and Android. The disabled plugin preserves your normal update configuration.

Add this profile to `eas.json`:

```json
{
  "build": {
    "drafts-device": {
      "developmentClient": false,
      "distribution": "internal",
      "channel": "drafts",
      "environment": "preview",
      "credentialsSource": "remote",
      "env": { "DRAFTS_ENABLED": "1" },
      "ios": { "simulator": false, "buildConfiguration": "Release" }
    }
  }
}
```

Register your phone and create the first signed build:

```sh
npx eas-cli@23.2.0 device:create
DRAFTS_ENABLED=1 npx eas-cli@23.2.0 build --profile drafts-device --platform ios
```

Install it on a registered device. For a simulator, use the `drafts-simulator` profile in the supplied template, or build locally with `DRAFTS_ENABLED=1 npx expo run:ios --configuration Release --no-bundler`.

The [setup guide](https://github.com/davidmokos/expo-drafts/blob/main/docs/setup.md) includes copyable workflows for an app at the repository root, required repository settings, and signing setup. No hosted catalog or application backend is needed.

The floating button appears automatically. Tap **Sign in to Expo** and choose an account with access to this EAS project. The browser handles authentication; expo-drafts never asks for your password. The account button lets you sign out, clearing the saved session and in-memory lists. No React provider, screen, or JavaScript initialization is required. To open it from your app:

```ts
import { Platform } from 'react-native';

// Only in an iOS build that includes expo-drafts.
if (Platform.OS === 'ios') {
  const { openDrafts } = await import('expo-drafts');
  await openDrafts();
}
```

Avoid an unconditional `expo-drafts` import in shared Android or web code. The package also exposes `setDraftsVisible()` and `getDraftsState()` on iOS.

The button's visibility applies to the current process. Include the plugin with `{ enabled: false }` in production builds. Without the plugin's native enabled flag, the installed module does not display a picker.

The picker's **Running** section identifies the active bundle immediately, including the first launch after installing another native build. It shows the preview name when the running EAS Update exactly matches a catalog entry. Otherwise, it identifies the bundle included in the build or a downloaded update by its own ID. Tap this row for the full bundle ID, creation time, app version, and native runtime. Sharing a runtime does not make two bundles the same version.

When a downloaded update is running, **Run bundled version** appears directly below Running. It reloads the JavaScript bundle included in the installed native build without a download or a catalog connection. The selection survives restarting the app. You can then select another compatible PR as usual. Installing a different native build changes which bundled version this action returns to.

## Native builds from the picker

Tap an incompatible draft to see its native build actions. A finished build with the exact iOS runtime and configured device profile offers **Install compatible build**, which hands the build directly to iOS's installer without opening the EAS website. Confirm the system installation dialog, then go to the Home Screen. Wait for the app icon to finish installing before reopening the app. Queued and running builds show progress. If no matching build exists, **Request Build** opens a prefilled GitHub issue; sign in and submit it to start the build workflow. The app refreshes build status when you return, on pull to refresh, and every 30 seconds while an incompatible build is in progress and the picker is visible.

After the installer opens, **Installation requested** shows an activity indicator for up to 15 minutes. iOS does not report download progress or completed installation to the app. The exact selected update remains saved for seven days. Reopen the matching native build to resume it automatically; a failed or interrupted attempt offers an explicit retry. **Cancel Auto-Open** clears the selection without canceling an installation already accepted by iOS.

Build requests require repository write access. Trusted GitHub Actions code validates the request against the current EAS channel update and the PR's source commit before dispatching EAS Workflows. The EAS workflow reuses an existing matching internal device build, or creates one. Only a completed build with verified project, runtime, profile, and device distribution metadata gets an install link. Publishing and signing credentials remain in GitHub/EAS.

Your iPhone must be included in the build's ad hoc provisioning profile. Installation requires the system installation flow and replaces the app's native binary. Reopen the app afterward; only updates matching that build's runtime will be selectable. TestFlight is not required.

Build discovery uses EAS directly. The GitHub build request URL is optional; existing build installation and update selection work without it. See [native build setup](https://github.com/davidmokos/expo-drafts/blob/main/docs/native-builds.md) for signing, workflows, and integration in another repository.

## Publish from PRs

Start with the [consumer setup guide](https://github.com/davidmokos/expo-drafts/blob/main/docs/setup.md) and [app-root templates](https://github.com/davidmokos/expo-drafts/tree/main/templates/app-root). The [workflow guide](https://github.com/davidmokos/expo-drafts/blob/main/docs/workflow.md) also documents this repository's monorepo example. Each same-repository PR uploads its exact source commit to EAS Workflows, which publishes the iOS update to `draft-pr-N`. Each update message includes the PR title, and the picker discovers the publication directly from EAS. GitHub does not publish or serve a catalog. Fork PRs do not receive Expo credentials.

For a manual publication:

```sh
DRAFTS_ENABLED=1 npx eas-cli@23.2.0 update --platform ios \
  --channel draft-search --message 'Search redesign' \
  --environment preview --non-interactive
```

Refresh the picker after publishing. EAS enforces your Expo account's project permissions. A successful list stays available in memory while later requests refresh it; signing out or losing project access clears it. Unsupported channel rollouts are reported explicitly rather than choosing an arbitrary branch.

For existing integrations, an explicitly configured `catalogUrl` still enables the optional custom HTTPS catalog mode, and `buildsCatalogUrl` supplies its build metadata. The legacy catalog export CLIs remain available for that mode. Drafts Lab and the included workflows use direct EAS discovery.

## Test app

The following commands are for contributors in this repository, not for installing the package into another app.

`example/` is Drafts Lab, an Expo app linked to `@mokosdavid/expo-drafts-lab`. It uses `@expo/ui` controls with Expo Router's native tab bar and navigation stacks. Library has book details and reading progress, Focus has a timer, Studio has the system color picker, and Settings opens Drafts and shows the running bundle. Its native draft picker reads EAS directly after Expo sign-in.

Each PR changes `example/src/data/preview.ts` to choose its starting tab, sample content, timer defaults, and palette. All screens live in the shared native build, so these preview changes can be published as EAS Updates. Adding or changing native dependencies requires a new compatible build.

PRs #1 through #4 share one native runtime. PR #5 changes `ios.supportsTablet` to `false` and requires a different native build, providing a real native upgrade to try from the picker. The original manual channels remain in EAS with earlier runtimes. See the [validation record](https://github.com/davidmokos/expo-drafts/blob/main/docs/ios-validation.md) for the current builds, exact update IDs, and completed checks.

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

The script builds Release without Metro. If the existing profile is managed by Xcode, use Automatic signing on the app target in Xcode. See the [historical iPhone validation notes](https://github.com/davidmokos/expo-drafts/blob/main/docs/ios-validation.md#historical-physical-iphone-validation) for completed local installations of earlier native revisions.

For an EAS cloud build, register the device with EAS and build the `drafts-device` profile from `example/`:

```sh
eas device:create
eas build --profile drafts-device --platform ios
```

This creates a signed internal Release build. Install it from the EAS build page on a device included in its provisioning profile. The simulator and device profiles use the same native runtime, so both can select the same compatible PR updates. EAS installs the parent package through the example's build hook; see the [workflow guide](https://github.com/davidmokos/expo-drafts/blob/main/docs/workflow.md) for its fingerprint handling.

Run `npm test` for catalog, build request, workflow, and plugin validation. Run `bash tests/ios/run.sh` for the iOS cache transactions, exact build matching, installation URL checks, and native request URL round-trip through the CI parser. Native projects in the example are generated by Expo prebuild and are not committed.

See the [iOS validation record](https://github.com/davidmokos/expo-drafts/blob/main/docs/ios-validation.md) for simulator coverage and the published test updates.

## Recovery and limits

Channel switching keeps Expo's embedded fallback and anti-bricking measures enabled. This package does not override the update URL or disable those measures. A native process crash still ends the app; reopen it to allow Expo recovery and access the picker again. Recovery restores the previous channel. If Expo has already removed its cached update after a relaunch, the app may return to the embedded version.

The iOS cache adapter uses Expo SDK 57's `updates` and `json_data` schema through public `UpdatesDatabase` APIs. Review it when upgrading the SDK. The picker serializes its own switches; app code must not start another `expo-updates` download or reload during a switch.

The same app installation shares its local data across drafts. Keep database migrations and persisted state compatible across the PRs you switch between. Switching EAS Updates changes JavaScript and assets. Installing a compatible build replaces the native binary.

Creating a GitHub build request can consume EAS build minutes. Opening the request page alone starts no build. Closing a PR does not delete its EAS channel. Direct discovery uses your Expo account permissions; custom catalog authentication remains the responsibility of that integration.

The design follows Expo's [channel surfing](https://docs.expo.dev/eas-update/channel-surfing/), [runtime compatibility](https://docs.expo.dev/eas-update/runtime-versions/), and [error recovery](https://docs.expo.dev/eas-update/error-recovery/) behavior. Native implementation references were inspected in the local Expo repository.

MIT
