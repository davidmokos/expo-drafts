# Native build requests and installation

The picker reads two catalogs. `catalog.json` lists EAS Updates, and `build-catalog.json` lists native device builds and request progress. Both belong to one EAS project. Build matching requires the exact runtime, iOS platform, and configured build profile. An unrelated newer build is never substituted.

## Request and install flow

1. Open an incompatible draft. If a verified matching build is ready, select **Install compatible build** to hand it directly to the iOS installer. Confirm installation in the system dialog, then go to the Home Screen and wait for the app icon to finish installing. The app does not open the EAS website.
2. If no build is available, select **Request Build**. Safari opens a prefilled GitHub issue with the preview's identity. Sign in to GitHub and submit the issue. Merely opening the page does not create a build.
3. GitHub Actions verifies that the requester has write, maintain, or admin access. It reads the current catalog from the trusted catalog branch, verifies the update ID and runtime, and uses the catalog's source commit. PRs must still point to that exact commit in the same repository. A stale request must be refreshed.
4. The workflow publishes a queued record, installs source dependencies, and verifies that the checkout reproduces the requested fingerprint. It uploads the source with the trusted EAS build workflow.
5. EAS `get-build` looks for the exact runtime and internal device profile. A matching build can serve multiple PRs. If necessary, the `build` job creates an iPhone build using configured remote signing credentials.
6. GitHub observes EAS, publishes progress, and verifies the finished artifact before publishing its installation page. Return to the picker or pull to refresh to see the result. While a build is in progress, the visible picker refreshes every 30 seconds.
7. Complete installation on the phone and reopen the app. The new native binary determines which updates are compatible.

A new native binary with the same bundle identifier replaces the current app. It does not make every older runtime compatible. App data remains shared between drafts, so coordinate database migrations and persisted state.

The picker retains an **Installation requested** row after the URL handoff, including across picker and app restarts. Its activity indicator means a request is pending; iOS provides no confirmation or download-progress callback for this flow. The row offers retry and **Hide Status** if the system prompt was canceled. Hiding it does not cancel an installation already accepted by iOS. The record is discarded after 15 minutes or when the app observes another native runtime.

The **Running** row always describes the actual launched bundle, independently of installation requests and catalog availability. An embedded bundle has its own UUID and may differ from every published EAS Update. Only an exact update ID and runtime match can supply a preview name. Tapping the row shows the full identity and native app version.

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
  catalogUrl: 'https://api.github.com/repos/OWNER/REPO/contents/catalog.json?ref=drafts-catalog',
  buildsCatalogUrl: 'https://api.github.com/repos/OWNER/REPO/contents/build-catalog.json?ref=drafts-catalog',
  buildRequestUrl: 'https://github.com/OWNER/REPO/issues/new',
  buildProfile: 'drafts-device',
}]
```

Set `runtimeVersion: { policy: 'fingerprint' }` explicitly if the app previously used a static or app-version runtime. Install `expo-drafts` and `expo-updates`, then create a new native build to include the plugin settings. Disable the plugin in production. Avoid competing automatic update download/reload logic in the preview build.

Enable GitHub Issues, add the repository secret `EXPO_TOKEN`, and allow Actions to write repository contents. The request workflow grants `issues: read` to inspect requests; it verifies the actor's repository permission before using Expo credentials. Public users can open issues but cannot start builds without repository write access.

Adapt [the GitHub request workflow](../.github/workflows/native-build.yml) and [the EAS workflow](../example/.eas/workflows/build-draft.yml). Change `DRAFT_PROJECT_ID`, the app directory and dependency installation steps, the bundle identifier in `get-build`, and profile names together. Keep the trusted CLI helpers and EAS workflow on the default branch. The GitHub job checks them out separately from the requested source; source dependencies do not select the control code. The example's parent-package installation hook is specific to this monorepo and is not needed for a normal consuming app.

The included hosting uses a public GitHub catalog. A private repository's Contents URL cannot be fetched anonymously by the app. Private catalog authentication requires a separate integration; do not embed GitHub or Expo access tokens in the native app or public JSON.

## Signing

Register each test device with `eas device:create`, then configure the internal profile's signing credentials with `eas credentials:configure-build --platform ios --profile drafts-device`. Use remote credentials for the supplied workflow. A device must be included in the actual provisioning profile, not just recorded in the EAS device list.

The example enables `refresh_ad_hoc_provisioning_profile: true`. This requires an App Store Connect API key assigned to the app for EAS to refresh its managed profile without an interactive Apple sign-in. Existing valid signing artifacts can be reused. See [Expo's internal distribution and CI requirements](https://docs.expo.dev/build/internal-distribution/).

The app hands a verified EAS installation manifest to iOS using `itms-services`. iOS downloads and installs the signed app after confirmation. Reopen the app after installation and select the draft. TestFlight is not required for this ad hoc workflow.

The installer must be able to fetch the manifest and IPA without the app's browser cookies. The example uses EAS's default unauthenticated internal build access. Keep private builds behind your existing access controls; opening the EAS website is an explicit fallback when direct installation is unavailable. See [Apple's wireless installation documentation](https://support.apple.com/en-gb/guide/deployment/depce7cefc4d/1/web) and [Expo's internal distribution access settings](https://docs.expo.dev/build/internal-distribution/).

## Direct installation

The package derives the manifest URL from the configured EAS project UUID and the verified build UUID:

```text
https://api.expo.dev/v2/projects/{projectId}/builds/{buildId}/manifest.plist
```

This is the endpoint used by EAS CLI for internal iOS installation. The app validates the manifest, then opens an `itms-services` URL through UIKit. The catalog retains the stable build identity. It does not store the manifest's temporary signed IPA URL.

The system installer requires a registered physical iPhone or iPad supported by the build. Foundation tests cover URL and manifest validation; the simulator's install action displays a device-only message before requesting a manifest. The app can confirm that iOS accepted the handoff, not whether the user confirmed or the installation completed.

## Verification and failure handling

The EAS result must identify the expected workflow, project, runtime, source request, and build profile. A newly created build must match the requested commit. A reused build may have a different commit if its runtime and profile match. A second metadata lookup verifies the selected build ID, project, runtime, internal distribution, physical-device target, completion, and artifact availability. Simulator, store, unfinished, expired, and unknown-runtime results cannot become installable catalog entries.

Catalog writes use normal Git pushes and retry conflicts while preserving both files. Each request has an identity and timestamp; late progress cannot regress a final result. A ready build remains available if a duplicate request fails. Request failures appear in GitHub Actions and, after a request was accepted, as a failed build state in the picker. An observation timeout leaves the EAS build running so a later request can find and reuse it.

The standard GitHub workflow also supports manual dispatch with the current channel, iOS update ID, and runtime. It uses the same requester and catalog validation as a request submitted from the app.
