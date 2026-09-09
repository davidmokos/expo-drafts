# Native build requests and installation

The picker signs in to Expo and reads updates and native builds directly from EAS. Build matching requires the exact EAS project, runtime, iOS platform, and configured build profile. An unrelated newer build is never substituted. GitHub handles authenticated build requests; it does not host the discovery data.

## Request and install flow

1. Open an incompatible draft. If a verified matching build is ready, select **Install compatible build** to hand it directly to the iOS installer. Confirm installation in the system dialog, then go to the Home Screen and wait for the app icon to finish installing. The app does not open the EAS website.
2. If no build is available, select **Request Build**. Safari opens a prefilled GitHub issue with the preview's identity. Sign in to GitHub and submit the issue. Merely opening the page does not create a build.
3. GitHub Actions verifies that the requester has write, maintain, or admin access. It queries the latest iOS update on the requested EAS channel, verifies the exact update ID and runtime, and uses EAS's source commit. The channel must be active and route to one branch without a rollout or rollback. PRs must still point to that exact commit in the same repository. A stale request must be refreshed.
4. The workflow installs source dependencies and verifies that the checkout reproduces the requested fingerprint. It uploads the source with the trusted EAS build workflow.
5. EAS `get-build` looks for the exact runtime and internal device profile. A matching build can serve multiple PRs. If necessary, the `build` job creates an iPhone build using configured remote signing credentials.
6. GitHub observes EAS and verifies the finished artifact, saving the result and EAS links in its Actions report. The picker reads queued, running, and finished builds from EAS itself. Return to the picker or pull to refresh to see the result. While a build is in progress, the visible picker refreshes every 30 seconds.
7. Complete installation on the phone and reopen the app. The new native binary determines which updates are compatible.

Before EAS creates or finds a native build, the request can be running in GitHub Actions without a build appearing in the picker. Dependency, permission, source, and fingerprint failures at that stage are visible in the GitHub run. Opening the issue page alone never means a build was queued.

A new native binary with the same bundle identifier replaces the current app. It does not make every older runtime compatible. App data remains shared between drafts, so coordinate database migrations and persisted state.

The picker retains an **Installation requested** row after the URL handoff, including across picker and app restarts. Its activity indicator means a request is pending; iOS provides no confirmation or download-progress callback for this flow. The row offers retry and **Hide Status** if the system prompt was canceled. Hiding it does not cancel an installation already accepted by iOS. The record is discarded after 15 minutes or when the app observes another native runtime.

The **Running** row always describes the actual launched bundle, independently of installation requests and EAS availability. An embedded bundle has its own UUID and may differ from every published EAS Update. Only an exact update ID and runtime match can supply a preview name. Tapping the row shows the full identity and native app version.

**Run bundled version** appears below Running while an EAS Update is active. It selects the installed build's embedded bundle locally, restores its original update headers, and verifies the exact bundle before reloading. It works offline and remains selected across app restarts. It does not install or downgrade native code, delete app data, or prevent selecting compatible PR updates afterward. Expo continues to manage its update cache and recovery.

## Configure another app

Use an internal Release device profile in `eas.json`:

```json
{
  "build": {
    "drafts-device": {
      "distribution": "internal",
      "channel": "drafts",
      "environment": "preview",
      "ios": { "simulator": false }
    }
  }
}
```

Configure the plugin in the preview app config:

```js
['expo-drafts', {
  buildRequestUrl: 'https://github.com/OWNER/REPO/issues/new',
  buildProfile: 'drafts-device',
}]
```

Set `runtimeVersion: { policy: 'fingerprint' }` explicitly if the app previously used a static or app-version runtime. Install `expo-drafts` and `expo-updates`, then create a new native build to include the plugin settings. Disable the plugin in production. Avoid competing automatic update download/reload logic in the preview build.

Enable GitHub Issues and add the repository secret `EXPO_TOKEN` with project build access. The request workflow grants `contents: read` and `issues: read`; it verifies the actor's repository permission before querying EAS. Public users can open issues but cannot start builds without repository write access.

Adapt [the GitHub request workflow](../.github/workflows/native-build.yml) and [the EAS workflow](../example/.eas/workflows/build-draft.yml). Change `DRAFT_PROJECT_ID`, the app directory and dependency installation steps, the bundle identifier in `get-build`, and profile names together. Keep the trusted CLI helpers and EAS workflow on the default branch. The GitHub job checks them out separately from the requested source; source dependencies do not select the control code. The example's parent-package installation hook is specific to this monorepo and is not needed for a normal consuming app.

Set `extra.eas.projectId` to the EAS project UUID. Each reviewer signs in to Expo in the app with project access. Discovery works through that session rather than an anonymous GitHub URL; do not embed CI access tokens in the native app. The old JSON export and writer commands remain optional for existing integrations, but the supplied workflows no longer publish those files.

## Signing

Register each test device with `eas device:create`, then configure the internal profile's signing credentials with `eas credentials:configure-build --platform ios --profile drafts-device`. Use remote credentials for the supplied workflow. A device must be included in the actual provisioning profile, not just recorded in the EAS device list.

The example defaults to `refresh_ad_hoc_provisioning_profile: true`. This requires an App Store Connect API key assigned to the app for EAS to refresh its managed profile without an interactive Apple sign-in. Issue-triggered requests always use this default. See [Expo's internal distribution and CI requirements](https://docs.expo.dev/build/internal-distribution/).

For a manual **Build requested iPhone preview** run, you can disable **refresh_ad_hoc_provisioning_profile** to reuse the existing EAS-managed profile. Use this only after checking that the profile and signing certificate remain valid, match the bundle identifier, and already include the intended devices. This avoids forced Apple profile refresh when Apple's service is unavailable. It does not add newly registered devices or repair expired or revoked credentials. Source, runtime, and finished-artifact verification still apply.

The app hands a verified EAS installation manifest to iOS using `itms-services`. iOS downloads and installs the signed app after confirmation. Reopen the app after installation and select the draft. TestFlight is not required for this ad hoc workflow.

The installer must be able to fetch the manifest and IPA without the app's browser cookies. The example uses EAS's default unauthenticated internal build access. Keep private builds behind your existing access controls; opening the EAS website is an explicit fallback when direct installation is unavailable. See [Apple's wireless installation documentation](https://support.apple.com/en-gb/guide/deployment/depce7cefc4d/1/web) and [Expo's internal distribution access settings](https://docs.expo.dev/build/internal-distribution/).

## Direct installation

The package derives the manifest URL from the configured EAS project UUID and the verified build UUID:

```text
https://api.expo.dev/v2/projects/{projectId}/builds/{buildId}/manifest.plist
```

This is the endpoint used by EAS CLI for internal iOS installation. The app validates the manifest, then opens an `itms-services` URL through UIKit. EAS supplies the stable build identity. The app does not persist the manifest's temporary signed IPA URL.

The system installer requires a registered physical iPhone or iPad supported by the build. Foundation tests cover URL and manifest validation; the simulator's install action displays a device-only message before requesting a manifest. The app can confirm that iOS accepted the handoff, not whether the user confirmed or the installation completed.

## Verification and failure handling

The EAS result must identify the expected workflow, project, runtime, source request, and build profile. A newly created build must match the requested commit. A reused build may have a different commit if its runtime and profile match. A second metadata lookup verifies the selected build ID, project, runtime, internal distribution, physical-device target, completion, and artifact availability. Simulator, store, unfinished, expired, and unknown-runtime results cannot become installable results.

A finished compatible EAS build can still be reused when a later request fails. EAS build failures appear in the picker; failures before EAS creates a build appear in GitHub Actions. The `native-build-request` artifact records the verified request, resolved runtime, EAS workflow, and finished build metadata when available. An observation timeout leaves the EAS build running so a later request can find and reuse it.

The standard GitHub workflow also supports manual dispatch with the current channel, iOS update ID, and runtime. It uses the same requester and direct EAS validation as a request submitted from the app.
