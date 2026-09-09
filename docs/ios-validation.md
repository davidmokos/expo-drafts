# iOS validation, September 8 and 9, 2026

The package and Drafts Lab were compiled in Release mode and tested on an iPhone 17 Pro Max simulator running iOS 26.3. No Metro server was running while the app selected, downloaded, or launched updates. The native build was compiled locally with Xcode; EAS hosted the actual remote updates.

The app uses Expo SDK 57, React Native 0.86.3, and expo-updates 57.0.21. Its EAS project is [@mokosdavid/expo-drafts-lab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab), and its bundle identifier is `dev.davidmokos.draftslab`.

## Current native picker and publications

Commit [`d3baee0`](https://github.com/davidmokos/expo-drafts/commit/d3baee015d8c9745014d527e515cfa7cd0a6a312) simplifies the picker to standard UIKit inset grouped rows, a search field, a Done button, pull to refresh, and a checkmark for the current update. Rows show a preview name and PR number, or a channel for manual previews. UIKit supplies the navigation title and system light or dark appearance. The draggable launcher is a `UIButton` with system glass styling on iOS 26 and later, and tinted styling on earlier versions. Commit hashes and runtime details remain in catalog metadata rather than the picker rows.

The managed iOS runtime is now `4b251db3e96d71fbcd20d1be7d63ddf929309765`. All four PR branches merged the native change without rewriting their history and republished successfully through EAS Workflows. Each artifact matched the catalog's exact iOS update ID, update group, source commit, and runtime.

| Preview | Channel | Current iOS update ID |
| ------- | ------- | --------------------- |
| [PR #1 workspace](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | `01a08311-256d-79a0-a5ae-0dc3fcaa1425` |
| [PR #2 Reading list](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | `01a08311-7c39-7dc5-bcc8-ded78524f3e6` |
| [PR #3 Focus timer](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | `01a08311-8da0-7f8f-bd0f-781515385bee` |
| [PR #4 Color studio](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | `01a08311-e533-7f04-aea2-5627a3acd506` |

All of these EAS workflows, GitHub publishing runs, and package checks passed:

| PR | EAS Workflow | GitHub publishing run | Package checks |
| -- | ------------ | --------------------- | -------------- |
| #1 | [01a08310-14ea](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08310-14ea-7854-95ec-4ae8cfac0bc1) | [34284195380](https://github.com/davidmokos/expo-drafts/actions/runs/34284195380) | [34284195345](https://github.com/davidmokos/expo-drafts/actions/runs/34284195345) |
| #2 | [01a08310-6f0c](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08310-6f0c-78d3-aeeb-dc7f75414b82) | [34284223680](https://github.com/davidmokos/expo-drafts/actions/runs/34284223680) | [34284223540](https://github.com/davidmokos/expo-drafts/actions/runs/34284223540) |
| #3 | [01a08310-696f](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08310-696f-79e0-a60f-3dbe1849618f) | [34284232251](https://github.com/davidmokos/expo-drafts/actions/runs/34284232251) | [34284232246](https://github.com/davidmokos/expo-drafts/actions/runs/34284232246) |
| #4 | [01a08310-b084](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08310-b084-787f-8ffc-cea025a0289c) | [34284244050](https://github.com/davidmokos/expo-drafts/actions/runs/34284244050) | [34284244140](https://github.com/davidmokos/expo-drafts/actions/runs/34284244140) |

[Catalog commit `38c5183`](https://github.com/davidmokos/expo-drafts/blob/38c5183a16a347cd6ebe8eaf01b2686b5b96b8d3/catalog.json) retains seven entries. The four PRs match the new runtime. The manual Amber and Ocean entries still use `49c985303fd99723dc5d59a62ef5e31c1c34d457`, and Camera experiment uses `drafts-lab-native-v2`; all three are incompatible with the new native revision. Incompatible rows display "Requires a different build" and cannot launch. "Find a Compatible Build" opens the configured EAS build page.

## Current simulator checks

- Launched PR workspace, Reading list, Focus timer, and Color studio through the native picker. Each app's diagnostic output showed its full update ID matching the current publications table and runtime `4b251db3e96d71fbcd20d1be7d63ddf929309765`.
- Reopened the picker on Reading list, Focus timer, and Color studio and confirmed each current entry had a checkmark.
- Checked the native picker in system light and dark appearance.
- Filtered the draft list with search and verified that tapping an incompatible draft did not launch it.
- Switched from Color studio to the older Reading list update and cold-restarted the app. Reading list reopened with exact ID `01a08311-7c39-7dc5-bcc8-ded78524f3e6` and the same runtime.

The historical checks below apply to the earlier runtime.

## Earlier published test updates

The earlier installed native runtime was `49c985303fd99723dc5d59a62ef5e31c1c34d457`. Compatibility in this table refers to that build.

| Draft             | Channel        | iOS update ID                          | Compatibility                               |
| ----------------- | -------------- | -------------------------------------- | ------------------------------------------- |
| Amber workspace   | `draft-amber`  | `01a0828a-57c7-7575-b5f1-bb2b6823bcaf` | Matches installed runtime                   |
| Ocean workspace   | `draft-ocean`  | `01a0828a-9e45-792b-a6af-7a7d58c7110d` | Matches installed runtime                   |
| Camera experiment | `draft-native` | `01a0827b-f2be-7704-9101-52d0e7c2b195` | Deliberate mismatch: `drafts-lab-native-v2` |
| PR workspace      | `draft-pr-1`   | `01a082cd-50d9-70ae-8908-2e7f73e03a18` | Matches installed runtime                   |
| Reading list      | `draft-pr-2`   | `01a082cf-6fd5-71ed-b40e-f6bcb49a31af` | Matches installed runtime                   |
| Focus timer       | `draft-pr-3`   | `01a082cf-4115-743b-9336-eeb9707e5a70` | Matches installed runtime                   |
| Color studio      | `draft-pr-4`   | `01a082ce-819c-70a7-9b38-7c776c99a4a1` | Matches installed runtime                   |

The Camera experiment uses an explicit test runtime to exercise the disabled state; it does not add camera functionality. Normal previews use the fingerprint runtime policy.

## Earlier simulator checks

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
- Launched Color studio from PR #4. Selecting a swatch changed the composition and hex value, saving a palette raised its collection count to one, and changing from Moonflower to Apricot hour changed the palette.
- Launched Focus timer from PR #3, selected five minutes, started the timer, and paused at `04:52`. Reset restored `05:00`.
- Launched Reading list from PR #2 and opened an article in its reader sheet. Finishing it raised read progress to one, and the Read filter showed only that article. Unsaving an article reduced the saved count, and the Saved filter showed only the remaining saved article.
- Verified each of the three running update IDs and runtimes against the catalog entries above.
- Cold-restarted Reading list and verified that its exact update ID persisted. The Read filter then showed its empty state because the demo's JavaScript state had reset.
- Switched from the newer Reading list update back to the older exact Color studio update. After a cold restart, Color studio reopened and the native picker marked its exact catalog entry as Running.
- Searched the seven-draft picker for "Camera" and got exactly one disabled result with "Native changes · Needs new EAS build." Tapping it did not launch an update, and Color studio remained active.

The demo interactions use state local to the current JavaScript session. Reading progress, saved palettes, and timer state reset when the app restarts or switches updates. The selected update itself persists across restarts.

## Earlier PR workflow validation

The repository's `EXPO_TOKEN` secret is configured. [PR #1](https://github.com/davidmokos/expo-drafts/pull/1) contains a JavaScript-only change to the default app screen, preserving the Amber and Ocean variants.

The initial source commit `e2ba419d0115027a88a2f08e1eed566ab4959405` triggered [Publish PR draft run 34272892017](https://github.com/davidmokos/expo-drafts/actions/runs/34272892017). At that point, GitHub Actions ran `eas update` directly. Both the `update` and `catalog` jobs passed, publishing iOS update `01a082a2-9417-7e29-8c7d-408a0980535f` in group `aadb27eb-945c-4c3c-a7d3-05af197d6715`.

The initial catalog job added `draft-pr-1` with the title "[example] previews a pull request from GitHub Actions" and the PR's source commit. Catalog commit `cba8486` contained four drafts, including the three earlier test entries. The simulator launched that exact update and retained it after a cold restart. [Check package run 34272892014](https://github.com/davidmokos/expo-drafts/actions/runs/34272892014) also passed.

After merging the EAS Workflows implementation into PR #1, source commit `4169cbb18aca43355a9cc50fc9de2219996e72dd` triggered [Publish PR draft run 34277347159](https://github.com/davidmokos/expo-drafts/actions/runs/34277347159). GitHub Actions uploaded the PR source and dispatched [EAS Workflow 01a082cc-40f3-7a24-8fc4-bb8a28493740](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a082cc-40f3-7a24-8fc4-bb8a28493740). The EAS update job verified the uploaded Git commit, published the update, and completed successfully.

The GitHub catalog job then replaced the `draft-pr-1` entry with iOS update `01a082cd-50d9-70ae-8908-2e7f73e03a18`, group `17e0f828-a8ac-46e0-8939-6152223441a7`, and the new source commit. The published artifact and live catalog agreed on these values. Both PR #1 publications resolved runtime `49c985303fd99723dc5d59a62ef5e31c1c34d457`. The simulator selected and launched the new EAS Workflow update, and its accessibility output confirmed the exact ID. [Check package run 34277347133](https://github.com/davidmokos/expo-drafts/actions/runs/34277347133) passed both the package checks and macOS cache tests.

Three further PRs exercised separate previews through the same EAS Workflows pipeline. All three EAS update jobs, GitHub publishing jobs, and package checks succeeded.

| Preview PR | EAS Workflow | GitHub publishing run | Package checks |
| ---------- | ------------ | --------------------- | -------------- |
| [#2 Reading list](https://github.com/davidmokos/expo-drafts/pull/2) | [01a082ce-434f](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a082ce-434f-738f-8472-3d99964e60b0) | [34277547731](https://github.com/davidmokos/expo-drafts/actions/runs/34277547731) | [34277547833](https://github.com/davidmokos/expo-drafts/actions/runs/34277547833) |
| [#3 Focus timer](https://github.com/davidmokos/expo-drafts/pull/3) | [01a082ce-0fb0](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a082ce-0fb0-7ff9-b299-12efdbfc1890) | [34277527677](https://github.com/davidmokos/expo-drafts/actions/runs/34277527677) | [34277527450](https://github.com/davidmokos/expo-drafts/actions/runs/34277527450) |
| [#4 Color studio](https://github.com/davidmokos/expo-drafts/pull/4) | [01a082cd-4cf9](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a082cd-4cf9-7895-a566-190ca60b037f) | [34277438141](https://github.com/davidmokos/expo-drafts/actions/runs/34277438141) | [34277438113](https://github.com/davidmokos/expo-drafts/actions/runs/34277438113) |

Their publishing runs overlapped. [Catalog commit `c34b626`](https://github.com/davidmokos/expo-drafts/blob/c34b626bd3171c98d21fda71bb6606e57c82740a/catalog.json) retained all seven channels, including PRs #1 through #4 and the three original drafts. Each new catalog entry matched its workflow artifact's exact update ID, update group, source commit, and runtime. All three used the existing installed runtime and launched without rebuilding the simulator app.

## Automated checks

- Package TypeScript build and ESLint passed.
- Example TypeScript validation and Expo dependency alignment passed.
- Seventeen Node tests passed, covering the config plugin, catalog validation, concurrent catalog publishers using a real bare Git repository, and EAS workflow identity checks, polling retries, and cancellation.
- Four native transaction tests passed using the production Swift cache adapter, real SQLite, and an EXUpdates test double. They exercise stale-fetch rollback, cached update adoption, interrupted-selection recovery, and transaction ownership.
- The complete iOS Release app compiled and installed successfully against the real Expo native modules.
- [GitHub Actions run 34270412779](https://github.com/davidmokos/expo-drafts/actions/runs/34270412779) passed both the package checks and macOS transaction tests for implementation commit `3f528cf`.
- A clean macOS checkout and Ubuntu CI using Node 24 both resolved the iOS runtime to `49c985303fd99723dc5d59a62ef5e31c1c34d457`. The CI result is recorded in [run 34271935734](https://github.com/davidmokos/expo-drafts/actions/runs/34271935734).
- `npm pack` succeeded with generated Android build files excluded.

## Physical iPhone validation

A local signed Release build of the simplified native picker completed with runtime `4b251db3e96d71fbcd20d1be7d63ddf929309765`, and `codesign --verify --deep --strict` passed. `devicectl` installed and activated it on the user's iPhone 17 Pro Max running iOS 27 Beta, and a subsequent process check confirmed that the same app process was still running. Signing reused the existing Xcode-managed profile with Automatic signing, without a fresh Apple login. The installation was local; no EAS cloud device build was run. This confirms installation and process launch, with UI interaction checks recorded separately for the simulator.

The earlier app build used local Xcode 26.6 in Release mode for `iphoneos` with an existing Xcode-managed development wildcard provisioning profile. The profile matched the connected phone and available signing certificate. Automatic signing was configured only on the app target after manual signing rejected the managed profile. No new Apple login was required.

`codesign --verify --deep --strict` passed for the resulting app. Its embedded `EXUpdates.bundle` contained runtime fingerprint `49c985303fd99723dc5d59a62ef5e31c1c34d457`, matching the earlier PR updates.

`devicectl` installed and launched the app on the user's iPhone 17 Pro Max running iOS 27 Beta. A subsequent process check confirmed that it was still running. This was a local installation; no EAS cloud device build was run. PR selection and the demo interactions were tested in the simulator. Physical-phone validation covers signing, installation, and process launch, without claiming phone UI tests.

## Limits

This version supports iOS SDK 57 only. Android validation is deferred. The cache adapter depends on Expo SDK 57's database schema and requires review when upgrading Expo. App code must not start a concurrent expo-updates download or reload during a picker switch. See the README for recovery behavior and shared app data considerations.
