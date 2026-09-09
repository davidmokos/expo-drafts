# Native build requests and installation

The picker reads two catalogs. `catalog.json` lists EAS Updates, and `build-catalog.json` lists native device builds and request progress. Both belong to one EAS project. Build matching requires the exact runtime, iOS platform, and configured build profile. An unrelated newer build is never substituted.

## Request and install flow

1. Open an incompatible draft. If a verified matching build is ready, select **Install Compatible Build** to open its EAS installation page.
2. If no build is available, select **Request Build**. Safari opens a prefilled GitHub issue with the preview's identity. Sign in to GitHub and submit the issue. Merely opening the page does not create a build.
3. GitHub Actions verifies that the requester has write, maintain, or admin access. It reads the current catalog from the trusted catalog branch, verifies the update ID and runtime, and uses the catalog's source commit. PRs must still point to that exact commit in the same repository. A stale request must be refreshed.
4. The workflow publishes a queued record, installs source dependencies, and verifies that the checkout reproduces the requested fingerprint. It uploads the source with the trusted EAS build workflow.
5. EAS `get-build` looks for the exact runtime and internal device profile. A matching build can serve multiple PRs. If necessary, the `build` job creates an iPhone build using configured remote signing credentials.
6. GitHub observes EAS, publishes progress, and verifies the finished artifact before publishing its installation page. Return to the picker or pull to refresh to see the result. While a build is in progress, the visible picker refreshes every 30 seconds.
7. Complete installation on the phone and reopen the app. The new native binary determines which updates are compatible.

A new native binary with the same bundle identifier replaces the current app. It does not make every older runtime compatible. App data remains shared between drafts, so coordinate database migrations and persisted state.

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

The app opens a verified EAS build page for installation. It does not download or silently replace its own executable, and no TestFlight setup is required for this ad hoc workflow.

## Verification and failure handling

The EAS result must identify the expected workflow, project, runtime, source request, and build profile. A newly created build must match the requested commit. A reused build may have a different commit if its runtime and profile match. A second metadata lookup verifies the selected build ID, project, runtime, internal distribution, physical-device target, completion, and artifact availability. Simulator, store, unfinished, expired, and unknown-runtime results cannot become installable catalog entries.

Catalog writes use normal Git pushes and retry conflicts while preserving both files. Each request has an identity and timestamp; late progress cannot regress a final result. A ready build remains available if a duplicate request fails. Request failures appear in GitHub Actions and, after a request was accepted, as a failed build state in the picker. An observation timeout leaves the EAS build running so a later request can find and reuse it.

The standard GitHub workflow also supports manual dispatch with the current channel, iOS update ID, and runtime. It uses the same requester and catalog validation as a request submitted from the app.
