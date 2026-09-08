# iOS validation, September 8, 2026

The package and Drafts Lab were compiled in Release mode and tested on an iPhone 17 Pro Max simulator running iOS 26.3. No Metro server was running while the app selected, downloaded, or launched updates. The native build was compiled locally with Xcode; EAS hosted the actual remote updates.

The app uses Expo SDK 57, React Native 0.86.3, and expo-updates 57.0.21. Its EAS project is [@mokosdavid/expo-drafts-lab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab), and its bundle identifier is `dev.davidmokos.draftslab`.

## Published test updates

The installed native runtime is `49c985303fd99723dc5d59a62ef5e31c1c34d457`.

| Draft             | Channel        | iOS update ID                          | Compatibility                               |
| ----------------- | -------------- | -------------------------------------- | ------------------------------------------- |
| Amber workspace   | `draft-amber`  | `01a0828a-57c7-7575-b5f1-bb2b6823bcaf` | Matches installed runtime                   |
| Ocean workspace   | `draft-ocean`  | `01a0828a-9e45-792b-a6af-7a7d58c7110d` | Matches installed runtime                   |
| Camera experiment | `draft-native` | `01a0827b-f2be-7704-9101-52d0e7c2b195` | Deliberate mismatch: `drafts-lab-native-v2` |
| PR workspace      | `draft-pr-1`   | `01a082cd-50d9-70ae-8908-2e7f73e03a18` | Matches installed runtime                   |

The Camera experiment uses an explicit test runtime to exercise the disabled state; it does not add camera functionality. Normal previews use the fingerprint runtime policy.

## Simulator checks

- Launched the embedded app without a development server.
- Opened the native picker using its floating button.
- Switched embedded → Amber → Ocean → Amber, verifying the running app's exact update ID after each switch.
- Reopened the app and confirmed the older cached Amber update still launched.
- Temporarily routed `draft-ocean` to the Amber branch while the catalog still advertised Ocean. Selecting Ocean was rejected with a refresh message. A cold restart still launched Amber.
- Restored the Ocean channel mapping and successfully switched to Ocean again.
- Confirmed Camera experiment is disabled, shows “Needs new EAS build,” and does not launch when tapped.
- Searched for Ocean, verified that only its entry remained, then dismissed search and recovered all three entries.
- Dragged the floating button to the opposite edge and opened the picker from its new position.
- Opened the EAS build link in Safari. The Expo project requires login in the simulator browser; no cloud build was requested.
- Reopened the app on Ocean and verified its exact update ID persisted.
- Selected the first update published for PR #1 through GitHub Actions and confirmed the app showed "PR workspace" and "Published from GitHub Actions." Its running update ID matched `01a082a2-9417-7e29-8c7d-408a0980535f`.
- Cold-restarted the app and confirmed it reopened on that PR workspace update with the same exact ID.
- After moving publication to EAS Workflows, selected the replacement PR #1 update. The app's accessibility output reported the exact new ID `01a082cd-50d9-70ae-8908-2e7f73e03a18`.

## PR workflow validation

The repository's `EXPO_TOKEN` secret is configured. [PR #1](https://github.com/davidmokos/expo-drafts/pull/1) contains a JavaScript-only change to the default app screen, preserving the Amber and Ocean variants.

The initial source commit `e2ba419d0115027a88a2f08e1eed566ab4959405` triggered [Publish PR draft run 34272892017](https://github.com/davidmokos/expo-drafts/actions/runs/34272892017). At that point, GitHub Actions ran `eas update` directly. Both the `update` and `catalog` jobs passed, publishing iOS update `01a082a2-9417-7e29-8c7d-408a0980535f` in group `aadb27eb-945c-4c3c-a7d3-05af197d6715`.

The initial catalog job added `draft-pr-1` with the title "[example] previews a pull request from GitHub Actions" and the PR's source commit. Catalog commit `cba8486` contained four drafts, including the three earlier test entries. The simulator launched that exact update and retained it after a cold restart. [Check package run 34272892014](https://github.com/davidmokos/expo-drafts/actions/runs/34272892014) also passed.

After merging the EAS Workflows implementation into PR #1, source commit `4169cbb18aca43355a9cc50fc9de2219996e72dd` triggered [Publish PR draft run 34277347159](https://github.com/davidmokos/expo-drafts/actions/runs/34277347159). GitHub Actions uploaded the PR source and dispatched [EAS Workflow 01a082cc-40f3-7a24-8fc4-bb8a28493740](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a082cc-40f3-7a24-8fc4-bb8a28493740). The EAS update job verified the uploaded Git commit, published the update, and completed successfully.

The GitHub catalog job then replaced the `draft-pr-1` entry with iOS update `01a082cd-50d9-70ae-8908-2e7f73e03a18`, group `17e0f828-a8ac-46e0-8939-6152223441a7`, and the new source commit. The published artifact and live catalog agreed on these values. Both PR #1 publications resolved runtime `49c985303fd99723dc5d59a62ef5e31c1c34d457`. The simulator selected and launched the new EAS Workflow update, and its accessibility output confirmed the exact ID. [Check package run 34277347133](https://github.com/davidmokos/expo-drafts/actions/runs/34277347133) passed both the package checks and macOS cache tests.

## Automated checks

- Package TypeScript build and ESLint passed.
- Example TypeScript validation and Expo dependency alignment passed.
- Seventeen Node tests passed, covering the config plugin, catalog validation, concurrent catalog publishers using a real bare Git repository, and EAS workflow identity checks, polling retries, and cancellation.
- Four native transaction tests passed using the production Swift cache adapter, real SQLite, and an EXUpdates test double. They exercise stale-fetch rollback, cached update adoption, interrupted-selection recovery, and transaction ownership.
- The complete iOS Release app compiled and installed successfully against the real Expo native modules.
- [GitHub Actions run 34270412779](https://github.com/davidmokos/expo-drafts/actions/runs/34270412779) passed both the package checks and macOS transaction tests for implementation commit `3f528cf`.
- A clean macOS checkout and Ubuntu CI using Node 24 both resolved the iOS runtime to `49c985303fd99723dc5d59a62ef5e31c1c34d457`. The CI result is recorded in [run 34271935734](https://github.com/davidmokos/expo-drafts/actions/runs/34271935734).
- `npm pack` succeeded with generated Android build files excluded.

## Limits

This version supports iOS SDK 57 only. Android validation is deferred. The cache adapter depends on Expo SDK 57's database schema and requires review when upgrading Expo. App code must not start a concurrent expo-updates download or reload during a picker switch. See the README for recovery behavior and shared app data considerations.
