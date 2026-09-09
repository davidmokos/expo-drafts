# iOS validation, September 8 and 9, 2026

This record separates the current native build actions from tests of earlier runtime revisions. Local simulator validation uses an iPhone 17 Pro Max running iOS 26.3. Native apps are compiled in Release mode with Xcode, and EAS hosts the remote updates.

The app uses Expo SDK 57, React Native 0.86.3, and expo-updates 57.0.21. Its EAS project is [@mokosdavid/expo-drafts-lab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab), and its bundle identifier is `dev.davidmokos.draftslab`.

## Current native build actions and publications

Commit [`6648eee`](https://github.com/davidmokos/expo-drafts/commit/6648eee37644a228993513699049e0cc0d32f7f8) adds build actions to incompatible drafts while retaining the standard UIKit picker. Its managed iOS runtime is `bd60359c5e450058d8f98dbde40e5beefb68fe2e`.

Build matching requires the exact iOS runtime and configured device profile. A verified ready build offers "Install compatible build"; queued and building records show progress and an available status link. Missing or failed builds offer "Request Build," which opens a prefilled GitHub issue. Signing in and submitting the issue is a separate browser action. Opening the form alone starts no build. Optional build metadata failures do not block compatible update selection. See [native build setup](native-builds.md) for the request and installation contract.

PRs #1 through #4 merged this native revision without rewriting their history and republished successfully. The EAS outputs, GitHub artifacts, and catalog agree on the exact iOS update ID, group, source commit, and runtime for each preview.

| Preview | Channel | iOS update ID |
| ------- | ------- | ------------- |
| [PR #1 workspace](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | `01a085fc-0bad-7dce-809c-282e18f00986` |
| [PR #2 Reading list](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | `01a085fc-05ab-7d36-95e2-e8ef19dd5776` |
| [PR #3 Focus timer](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | `01a085fc-233a-7582-9166-d5c70c3ce7fb` |
| [PR #4 Color studio](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | `01a085fc-01ae-72d1-9293-5159bdad68db` |

| PR | Source commit | Update group |
| -- | ------------- | ------------ |
| #1 | [`474a766`](https://github.com/davidmokos/expo-drafts/commit/474a766febfe5ed87c313ccde4db999569a16fcf) | `37165c0a-2865-47d2-ac4c-403ba1b18821` |
| #2 | [`de7c50c`](https://github.com/davidmokos/expo-drafts/commit/de7c50c70e0c2c95af001ed4fc38129e7a9afc14) | `02aff440-d060-4a7a-b55b-530f9c2a5692` |
| #3 | [`b6b9dcb`](https://github.com/davidmokos/expo-drafts/commit/b6b9dcbca93a1a4474315adfe579894147e13895) | `b90629d8-bc46-4912-8147-491c6321801e` |
| #4 | [`bf0bac6`](https://github.com/davidmokos/expo-drafts/commit/bf0bac6dfcb46e70b3516addc1acd03f60229c2b) | `357a9832-0156-4da4-bdaf-646c0ec433e5` |

All four EAS workflows, GitHub publishing runs, and package checks passed:

| PR | EAS Workflow | GitHub publishing run | Package checks |
| -- | ------------ | --------------------- | -------------- |
| #1 | [01a085fa-e6fc](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a085fa-e6fc-764a-b7c6-f5595456a288) | [34346963120](https://github.com/davidmokos/expo-drafts/actions/runs/34346963120) | [34346963250](https://github.com/davidmokos/expo-drafts/actions/runs/34346963250) |
| #2 | [01a085fa-e31e](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a085fa-e31e-7b06-b72a-d1e2261b3254) | [34346963251](https://github.com/davidmokos/expo-drafts/actions/runs/34346963251) | [34346963290](https://github.com/davidmokos/expo-drafts/actions/runs/34346963290) |
| #3 | [01a085fa-f7e8](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a085fa-f7e8-7d36-8d65-6a7f64490e8f) | [34346967886](https://github.com/davidmokos/expo-drafts/actions/runs/34346967886) | [34346967822](https://github.com/davidmokos/expo-drafts/actions/runs/34346967822) |
| #4 | [01a085fa-e477](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a085fa-e477-7415-b46a-3dad4d8492cd) | [34346966031](https://github.com/davidmokos/expo-drafts/actions/runs/34346966031) | [34346965995](https://github.com/davidmokos/expo-drafts/actions/runs/34346965995) |

[Catalog commit `670c758`](https://github.com/davidmokos/expo-drafts/blob/670c758545e56bc079866e8d4bf8cc4f29f32ac9/catalog.json) retained all four previews after their concurrent publications, alongside the original Amber, Ocean, and Camera experiment entries. Those three original entries require different runtimes.

[PR #5, iPhone-only native preview](https://github.com/davidmokos/expo-drafts/pull/5) changes `ios.supportsTablet` from `true` to `false`. Source commit [`cb89b16`](https://github.com/davidmokos/expo-drafts/commit/cb89b161139e384c899701c878d5812eded1e8a8) therefore resolves runtime `d9c89e22141f261165d3e46ae7268a3453a1e839`. Its [publishing run 34347112985](https://github.com/davidmokos/expo-drafts/actions/runs/34347112985) succeeded, and the live catalog records iOS update `01a085fd-aa00-7ed2-a220-94a658f88552` in group `3e06c3bf-d848-4d3e-950f-7716c3235e9c` on `draft-pr-5`. This is a native configuration change, so the current `bd60359…` build cannot launch it.

## Completed checks for native build actions

- Package TypeScript build, ESLint, and example TypeScript validation passed.
- All 34 Node tests passed, including build catalog validation, trusted build requests, EAS build result verification, config plugin options, and concurrent catalog publication.
- Four native transaction tests passed with real SQLite, covering rollback, cache adoption, startup recovery, and transaction ownership.
- Six Foundation build catalog test groups passed, covering exact runtime/platform/profile matching, build state ordering, project validation, verified installation URLs, encoded request bodies, and rejection of invalid GitHub request destinations.
- A request URL generated by native code round-tripped through browser query decoding and the trusted CI parser, preserving Unicode, quotes, newlines, and literal `+` characters.
- The local iOS Release app with runtime `bd60359c5e450058d8f98dbde40e5beefb68fe2e` compiled and installed on the simulator.
- The picker's Request Build action opened the browser's GitHub login handoff for the prefilled issue. This check covered opening the request page, not submitting an issue or starting a build.

## EAS request and build reuse checks

Authenticated build request [#6](https://github.com/davidmokos/expo-drafts/issues/6) used the native picker's request format. GitHub verified repository write access, the current PR #5 update and source commit, then dispatched EAS Workflows. The first attempt encountered an Apple server error while refreshing its ad hoc provisioning profile; the app displayed the failure and offered a new request.

The initial base build succeeded in EAS, but GitHub's result parser rejected an omitted simulator hint. Commit [`f610d43`](https://github.com/davidmokos/expo-drafts/commit/f610d43fcaf6f39d2637593cbc85146992aec1eb) accepts an absent workflow hint while still requiring explicit physical-device metadata from `eas build:view`. A regression fixture covers the actual EAS output. [Package checks 34348236814](https://github.com/davidmokos/expo-drafts/actions/runs/34348236814) passed.

A new request for PR #2 completed successfully in [GitHub run 34348283520](https://github.com/davidmokos/expo-drafts/actions/runs/34348283520) and [EAS Workflow 01a08608-ab03](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08608-ab03-7cd4-83d6-55caa65900bf). `get-build` reused PR #1's exact device build `163c8594-3ab2-4b7c-a120-b4be64646c7b` because the runtimes matched. The native build job was skipped. The published build catalog contained the verified ready record and canonical EAS installation link.

The PR #5 request succeeded on its second [GitHub run attempt](https://github.com/davidmokos/expo-drafts/actions/runs/34347685265/attempts/2) through [EAS Workflow 01a08608-c226](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08608-c226-7b47-b7b2-946a4b5c7034). It created device build [f4ffa64b](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/f4ffa64b-d926-4850-8834-c26271eb23bd) for the exact PR #5 source and runtime. The downloaded IPA passed strict signature verification, contained the `d9c89e…` fingerprint and iPhone-only device family `[1]`, and included the user's phone in its ad hoc profile. The build catalog's ready state appeared automatically in the visible picker. Its Install compatible build action opened the exact `f4ffa64b…` EAS page, displaying Finished and an Install button. The phone remains on the shared-runtime EAS build so the user can try this native upgrade from the picker.

## Current simulator and phone checks

The simulator launched PR workspace, Reading list, Focus timer, and Color studio through the native picker with runtime `bd60359c5e450058d8f98dbde40e5beefb68fe2e`. Each app displayed its exact published update ID from the current table. Reopening the picker marked the selected entry as current.

PR #5 remained incompatible on that binary. Its native actions showed request, queued, in-progress, and failed states from the live build catalog. Request Build opened GitHub's login handoff; View Build Status opened the exact GitHub run. A separate authenticated submission of the same native-format issue body exercised the build request trigger.

Installing a locally compiled iPhone-only simulator binary changed the runtime to `d9c89e22141f261165d3e46ae7268a3453a1e839`. Its actual `UIDeviceFamily` was `[1]`. PR #5 then became compatible, launched EAS Update `01a085fd-aa00-7ed2-a220-94a658f88552`, and retained that exact update after a cold restart. PRs #1–4 correctly required the other native runtime. Their ready build action opened the exact EAS page for build `163c8594…`, which displayed Finished and an Install button without requiring an Expo login. The simulator check stops at the EAS installation page; physical-device installation is verified separately below. Restoring the shared-runtime binary launched its compatible embedded fallback, without running the cached PR #5 update.

EAS device build [163c8594](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/163c8594-3ab2-4b7c-a120-b4be64646c7b) completed from PR #1 source. The downloaded IPA passed `codesign --verify --deep --strict`, contained the expected `bd60359…` fingerprint, and included the user's phone in its ad hoc profile. `devicectl` installed it on the connected iPhone 17 Pro Max running iOS 27 Beta, launched it, and confirmed the installed app process was still running. This confirms the real EAS artifact's installation and launch; UI interaction checks use the simulator.

The sections below preserve completed checks for earlier native runtimes. Their update IDs and physical-phone results belong to those revisions.

## Historical UIKit picker and publications

Commit [`d3baee0`](https://github.com/davidmokos/expo-drafts/commit/d3baee015d8c9745014d527e515cfa7cd0a6a312) simplifies the picker to standard UIKit inset grouped rows, a search field, a Done button, pull to refresh, and a checkmark for the current update. Rows show a preview name and PR number, or a channel for manual previews. UIKit supplies the navigation title and system light or dark appearance. The draggable launcher is a `UIButton` with system glass styling on iOS 26 and later, and tinted styling on earlier versions. Commit hashes and runtime details remain in catalog metadata rather than the picker rows.

That revision used managed iOS runtime `4b251db3e96d71fbcd20d1be7d63ddf929309765`. All four PR branches merged the native change without rewriting their history and republished successfully through EAS Workflows. Each artifact matched the catalog's exact iOS update ID, update group, source commit, and runtime.

| Preview | Channel | Historical iOS update ID |
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

[Catalog commit `38c5183`](https://github.com/davidmokos/expo-drafts/blob/38c5183a16a347cd6ebe8eaf01b2686b5b96b8d3/catalog.json) retained seven entries. The four PRs matched that runtime. The manual Amber and Ocean entries used `49c985303fd99723dc5d59a62ef5e31c1c34d457`, and Camera experiment used `drafts-lab-native-v2`; all three were incompatible with that native revision. Its incompatible rows displayed "Requires a different build" and could not launch. Its "Find a Compatible Build" link opened the configured EAS builds page. These labels predate the current per-draft build actions.

## Historical UIKit simulator checks

- Launched PR workspace, Reading list, Focus timer, and Color studio through the native picker. Each app's diagnostic output showed its full update ID matching the historical UIKit publications table and runtime `4b251db3e96d71fbcd20d1be7d63ddf929309765`.
- Reopened the picker on Reading list, Focus timer, and Color studio and confirmed each current entry had a checkmark.
- Checked the native picker in system light and dark appearance.
- Filtered the draft list with search and verified that tapping an incompatible draft did not launch it.
- Switched from Color studio to the older Reading list update and cold-restarted the app. Reading list reopened with exact ID `01a08311-7c39-7dc5-bcc8-ded78524f3e6` and the same runtime.

The historical checks below apply to the earlier runtime.

## Historical initial test updates

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

## Historical initial simulator checks

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

## Historical initial PR workflow validation

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

## Historical automated checks

- Package TypeScript build and ESLint passed.
- Example TypeScript validation and Expo dependency alignment passed.
- Seventeen Node tests passed, covering the config plugin, catalog validation, concurrent catalog publishers using a real bare Git repository, and EAS workflow identity checks, polling retries, and cancellation.
- Four native transaction tests passed using the production Swift cache adapter, real SQLite, and an EXUpdates test double. They exercise stale-fetch rollback, cached update adoption, interrupted-selection recovery, and transaction ownership.
- The complete iOS Release app compiled and installed successfully against the real Expo native modules.
- [GitHub Actions run 34270412779](https://github.com/davidmokos/expo-drafts/actions/runs/34270412779) passed both the package checks and macOS transaction tests for implementation commit `3f528cf`.
- A clean macOS checkout and Ubuntu CI using Node 24 both resolved the iOS runtime to `49c985303fd99723dc5d59a62ef5e31c1c34d457`. The CI result is recorded in [run 34271935734](https://github.com/davidmokos/expo-drafts/actions/runs/34271935734).
- `npm pack` succeeded with generated Android build files excluded.

## Historical physical iPhone validation

A local signed Release build of the simplified native picker completed with runtime `4b251db3e96d71fbcd20d1be7d63ddf929309765`, and `codesign --verify --deep --strict` passed. `devicectl` installed and activated it on the user's iPhone 17 Pro Max running iOS 27 Beta, and a subsequent process check confirmed that the same app process was still running. Signing reused the existing Xcode-managed profile with Automatic signing, without a fresh Apple login. The installation was local; no EAS cloud device build was run. This confirms installation and process launch, with UI interaction checks recorded separately for the simulator.

The earlier app build used local Xcode 26.6 in Release mode for `iphoneos` with an existing Xcode-managed development wildcard provisioning profile. The profile matched the connected phone and available signing certificate. Automatic signing was configured only on the app target after manual signing rejected the managed profile. No new Apple login was required.

`codesign --verify --deep --strict` passed for the resulting app. Its embedded `EXUpdates.bundle` contained runtime fingerprint `49c985303fd99723dc5d59a62ef5e31c1c34d457`, matching the earlier PR updates.

`devicectl` installed and launched the app on the user's iPhone 17 Pro Max running iOS 27 Beta. A subsequent process check confirmed that it was still running. This was a local installation; no EAS cloud device build was run. PR selection and the demo interactions were tested in the simulator. Physical-phone validation covers signing, installation, and process launch, without claiming phone UI tests.

## Limits

This version supports iOS SDK 57 only. Android validation is deferred. The cache adapter depends on Expo SDK 57's database schema and requires review when upgrading Expo. App code must not start a concurrent expo-updates download or reload during a picker switch. See the README for recovery behavior and shared app data considerations.
