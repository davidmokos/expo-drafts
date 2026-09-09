# Set up PR previews in another app

The npm package supplies the native picker. The workflow templates publish each PR to EAS and automatically ensure a compatible iPhone build. Use these templates for an Expo SDK 57 app whose `package.json`, lockfile, app config, and `eas.json` are at the Git repository root. They use npm, Node 24, `expo-drafts@0.1.0`, and EAS CLI 23.2.0. Android support is not included in this release.

## Install and configure the app

From your app directory:

```bash
npx expo install expo-updates
npm install --save-exact expo-drafts@0.1.0
npx eas-cli@23.2.0 init
```

Keep the EAS project UUID in `extra.eas.projectId`. Add the plugin to your existing app config, preserving its other fields and plugins. For example, in `app.config.js`:

```js
const enabled = process.env.DRAFTS_ENABLED === '1';

module.exports = ({ config }) => ({
  ...config,
  runtimeVersion: enabled ? { policy: 'fingerprint' } : config.runtimeVersion,
  plugins: [
    ...(config.plugins ?? []),
    [
      'expo-drafts',
      {
        enabled,
        channel: 'drafts',
        buildProfile: 'drafts-device',
        buildRequestUrl: 'https://github.com/OWNER/REPO/issues/new',
      },
    ],
  ],
});
```

Replace `OWNER/REPO` with your app repository. If `expo-drafts` is already in the plugin list, update that entry rather than adding another. The templates set `DRAFTS_ENABLED=1` only for iOS preview publication and builds; leave it unset for production, Android, and web. The plugin's update settings apply to the whole Expo config, so do not enable it in a shared Android build profile. Keep any other environment variables that affect native config consistent between GitHub's runtime check and the EAS `preview` environment.

No JavaScript import is required to show the picker. It needs a new native build containing the package and plugin settings. It cannot run inside Expo Go. When enabled, the plugin configures EAS Update and disables automatic update checking so the picker controls selection. Remove competing automatic download/reload code from preview builds.

Use the [fingerprint runtime policy](https://docs.expo.dev/eas-update/runtime-versions/) so native changes produce an incompatible runtime. Do not copy this repository's `example/fingerprint.config.js` or parent-package install hooks into your app. The npm package includes its compiled JavaScript and native sources.

## Copy the workflow templates

Run these commands from your app root, checking for existing files first:

```bash
mkdir -p .github/workflows .eas/workflows
cp -n node_modules/expo-drafts/templates/app-root/github/drafts.yml .github/workflows/drafts.yml
cp -n node_modules/expo-drafts/templates/app-root/github/native-build.yml .github/workflows/native-build.yml
cp -n node_modules/expo-drafts/templates/app-root/eas/publish-draft.yml .eas/workflows/publish-draft.yml
cp -n node_modules/expo-drafts/templates/app-root/eas/build-draft.yml .eas/workflows/build-draft.yml
```

`cp -n` preserves existing files. If one already exists, compare and merge it with the template. Merge the `build` profiles from [`templates/app-root/eas.json`](../templates/app-root/eas.json) into your `eas.json`; preserve your production profiles.

The device profile must use `developmentClient: false`, `distribution: "internal"`, remote credentials, and an iOS `Release` build with `simulator: false`. The optional `drafts-simulator` profile builds a Release simulator app. Neither needs a running Metro server. A development-client or Debug profile is not the preview binary used by these workflows.

Edit `.eas/workflows/build-draft.yml`: replace `com.example.app` in `existing_build.params.app_identifier` with your app's `ios.bundleIdentifier`. Keep the remaining identity names below unchanged for version 0.1.0:

| Setting                                        | Required value                                     |
| ---------------------------------------------- | -------------------------------------------------- |
| GitHub publisher file and workflow name        | `.github/workflows/drafts.yml`, `Publish PR draft` |
| EAS workflow filenames                         | `publish-draft.yml`, `build-draft.yml`             |
| EAS job keys                                   | `publish_update`, `existing_build`, `native_build` |
| Native build profile and plugin `buildProfile` | `drafts-device`                                    |
| Publication artifact                           | `draft-catalog-entry`                              |
| PR channel                                     | `draft-pr-<PR number>`                             |

The CLI verifies these names, exact source commits, project IDs, update IDs, and runtimes. Changing the names alone breaks that verification. Commit both GitHub workflows and both EAS workflows to the default branch before opening a preview PR.

## Configure GitHub and signing

In the app repository's Actions settings, add:

| Kind                | Name               | Value                                                                     |
| ------------------- | ------------------ | ------------------------------------------------------------------------- |
| Repository variable | `DRAFT_PROJECT_ID` | The UUID from `extra.eas.projectId`; this is not a secret                 |
| Repository secret   | `EXPO_TOKEN`       | Expo access token with update, workflow, and build access to that project |

Enable GitHub Issues if you want the picker's **Request Build** fallback. GitHub supplies its own `GITHUB_TOKEN`; no extra GitHub token or catalog-hosting branch is needed. See Expo's [programmatic access guide](https://docs.expo.dev/accounts/programmatic-access/) for token setup. Reviewers sign in to Expo in the app using their own accounts with project access. Never put `EXPO_TOKEN` in app config or an `EXPO_PUBLIC_` variable.

Before relying on unattended device builds, register your testers and configure remote signing credentials:

```bash
npx eas-cli@23.2.0 device:create
DRAFTS_ENABLED=1 npx eas-cli@23.2.0 credentials:configure-build --platform ios --profile drafts-device
DRAFTS_ENABLED=1 npx eas-cli@23.2.0 build --platform ios --profile drafts-device
```

Run the first build interactively so EAS can create a valid ad hoc profile containing your devices. Install that build on the registered iPhone. EAS builds consume the account's build quota.

Automatic PR requests reuse the existing profile with refresh disabled. They do not add newly registered devices or repair expired credentials. To include new devices, update the profile interactively or use the manual workflow's refresh option with an App Store Connect API key configured in EAS. A compatible existing build can still win the lookup, so rebuilding or re-signing for a new device is a separate signing task. See Expo's [internal distribution and CI requirements](https://docs.expo.dev/build/internal-distribution/).

## Channels and automatic builds

Open a same-repository PR. GitHub uploads its exact source commit, then an EAS Workflows `update` job publishes iOS JavaScript on `draft-pr-42`, for example. EAS creates the channel and matching branch on first publication. The update message is the PR title, which becomes the name shown in the picker. Another push replaces the current publication on that channel.

Keep the plugin's initial channel and the native build profile channel fixed at `drafts` across every PR. Only the publication channel changes to `draft-pr-N`. Do not put PR numbers in app config, bundle identifiers, or native request headers: that changes native inputs and prevents otherwise compatible PRs from sharing a build. The picker supplies the selected PR channel when it fetches an update.

Use active channels that route to one branch. Branch rollouts, update rollouts, paused channels, and rollback directives are unsupported for draft selection. The app reads EAS directly; the GitHub artifact is only a verification report.

A successful PR publication starts an independent native `workflow_run`. Trusted helpers validate the GitHub event and artifact against EAS, then serialize lookup/build jobs by project, platform, profile, and runtime. EAS reuses a completed compatible build, waits for a running match, or builds once when absent. A later compatible PR does not cancel the running build. GitHub may replace an older pending duplicate with the latest request.

The trusted helpers install separately from the app at pinned version 0.1.0 with lifecycle scripts disabled and remain outside its source archive. EAS workflow files come from the default-branch checkout, then are copied into the app's `.eas/workflows` directory and uploaded with its source. The workflow uploads local source, so no Expo GitHub App installation is required. Avoid enabling a second publisher for the same PR channels.

Fork PRs do not receive the Expo secret or start builds. Same-repository contributors can execute app code with CI access, so reserve branch write permission for trusted people and coding agents. Manual publication remains available in Actions, but only PR publications trigger automatic native builds. Use the manual native workflow or **Request Build** for a manually published preview.

## Check the integration

For a PR that changes only JavaScript, confirm **Publish PR draft** succeeds and the picker shows the PR title. The later **Build requested iPhone preview** run should report a reused compatible build. For a native dependency or plugin change, confirm the old binary shows the draft as incompatible and EAS creates a new runtime build. When that build is ready, install it and reopen the app to resume the saved exact draft.

The app can request installation; iOS completes it. Direct installation requires an internal build whose manifest and IPA the system installer can access. With Expo's default internal-build access this works without browser cookies; otherwise use your existing distribution flow.

These root-app templates are schema-validated and covered by local integration checks. The repository's example has completed live PR publication, automatic build creation, and compatible build reuse; a separate consumer project has not been published from these templates as part of the release checks.
