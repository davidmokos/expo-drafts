# iOS validation, September 8 and 9, 2026

This record separates the current Running and Installation requested UI from tests of earlier runtime revisions. Local simulator validation uses an iPhone 17 Pro Max running iOS 26.3. Native apps are compiled in Release mode with Xcode, and EAS hosts the remote updates.

The app uses Expo SDK 57, React Native 0.86.3, and expo-updates 57.0.21. Its EAS project is [@mokosdavid/expo-drafts-lab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab), and its bundle identifier is `dev.davidmokos.draftslab`.

## Running bundle and installation request recovery

Commit [`e37a0cb`](https://github.com/davidmokos/expo-drafts/commit/e37a0cb03f567c2dd8b622bbef41cf3894c9fb07) adds a native **Running** section and a persistent **Installation requested** status. The shared native runtime is `0b52dae850fb723b136dfed86d4051693ab14617`. PR #5's iPhone-only configuration resolves to `0d6f42d8d4867b6511c7631dfebef1a6c20ebf4f`.

The Running section identifies the actual launched bundle even before the catalog loads. Its details show the bundle's source, ID, creation time when available, and native runtime. Catalog names are used only when the running update matches the exact iOS update ID and runtime; an embedded bundle remains identified as embedded.

After iOS accepts the installer URL handoff, the app saves the requested build, draft, source runtime, target runtime, and request time. The picker shows Installation requested with an activity indicator and instructions to confirm Install, return to the Home Screen, and reopen the app afterward. This status does not confirm that the user accepted the system prompt, that a download is progressing, or that installation completed. It survives closing the picker and restarting the app for up to 15 minutes while the source runtime remains installed. Observing a different native runtime, expiry, or **Hide Status** clears it. **Try Again** is available when the catalog still contains the same draft and target runtime.

[Package checks 34361359097](https://github.com/davidmokos/expo-drafts/actions/runs/34361359097) passed for this exact commit. Package TypeScript build, ESLint, all 34 Node tests, example TypeScript validation, and managed iOS runtime resolution passed. The native test runner passed four SQLite transaction tests, six build catalog groups, three installer groups, four installation-state groups, five bundle-identity groups, and the native request URL round-trip through browser decoding and the trusted CI parser. The new groups cover persisted recovery, explicit dismissal, native runtime changes, expiry and future timestamps, invalid saved data, exact bundle identification, and offline or missing catalog metadata.

The local Release app compiled and installed on the simulator with the expected `0b52dae8…` fingerprint. On its first launch, Running and its details correctly identified the embedded bundle before the catalog was available. A valid saved installation-request fixture was then seeded into this simulator app's preferences to exercise recovery without a physical installation. The picker displayed the requested draft, activity indicator, and Home Screen instructions. Closing and reopening the picker preserved the status. Its action sheet offered Try Again and Hide Status; selecting Hide Status removed the persisted key and the status row while leaving Running visible. These are simulator UI and persistence checks for this revision; the physical installation checks below belong to the earlier native revision.

The simulator then selected Reading List through the native picker. Running identified **[example] Reading list** as an EAS Update, and the PR #2 row was marked current. Opening Running details showed exact bundle ID `01a08681-1475-787b-a51b-1a4ad8c986a6`, native runtime `0b52dae850fb723b136dfed86d4051693ab14617`, app version `1.0.0 (1)`, and the bundle creation time. The update ID and runtime matched the verified publication below.

### Publications for this revision

All five PR branches merged this native revision and republished successfully. Their EAS workflow outputs, GitHub artifacts, and catalog entries agree on each exact iOS update ID, source commit, group, and runtime. PRs #1–4 use `0b52dae850fb723b136dfed86d4051693ab14617`; PR #5 uses `0d6f42d8d4867b6511c7631dfebef1a6c20ebf4f` and requires its separate native build.

| Preview | Channel | Source commit | iOS update ID |
| --- | --- | --- | --- |
| [PR #1](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | [`733e00f`](https://github.com/davidmokos/expo-drafts/commit/733e00fc51861079b2357abb8bbb15533ca47cc0) | `01a08681-a97b-7972-9b98-35749a9a58dd` |
| [PR #2](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | [`e3d6f1e`](https://github.com/davidmokos/expo-drafts/commit/e3d6f1e83448c0f4f0ac620b52c446780807308e) | `01a08681-1475-787b-a51b-1a4ad8c986a6` |
| [PR #3](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | [`99d5317`](https://github.com/davidmokos/expo-drafts/commit/99d53177316821faed519d25bc7aa0166078d6d8) | `01a08680-dc7c-764a-9677-e95b823d405d` |
| [PR #4](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | [`f03cdf3`](https://github.com/davidmokos/expo-drafts/commit/f03cdf3035cabb3845cb3bc77cadf8faf366ad0e) | `01a08681-148e-742a-9b9a-f9662e75722b` |
| [PR #5](https://github.com/davidmokos/expo-drafts/pull/5) | `draft-pr-5` | [`9823ade`](https://github.com/davidmokos/expo-drafts/commit/9823adebd8a8e79b7056edb502f8eaedcf775cd4) | `01a08681-45fd-7294-85ed-926593be7598` |

All of these EAS workflows, GitHub publishing runs, and package checks passed:

| PR | EAS Workflow | GitHub publishing run | Package checks |
| --- | --- | --- | --- |
| #1 | [01a08680-72a5](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08680-72a5-7970-80bd-57b759002816) | [34361625811](https://github.com/davidmokos/expo-drafts/actions/runs/34361625811) | [34361625915](https://github.com/davidmokos/expo-drafts/actions/runs/34361625915) |
| #2 | [01a0867f-fbb8](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0867f-fbb8-7cd8-ae5a-e953ec56f4ef) | [34361567810](https://github.com/davidmokos/expo-drafts/actions/runs/34361567810) | [34361567950](https://github.com/davidmokos/expo-drafts/actions/runs/34361567950) |
| #3 | [01a0867f-d052](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0867f-d052-7f00-b4b5-70344912367a) | [34361564943](https://github.com/davidmokos/expo-drafts/actions/runs/34361564943) | [34361564891](https://github.com/davidmokos/expo-drafts/actions/runs/34361564891) |
| #4 | [01a0867f-ed3a](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0867f-ed3a-7df5-a48d-082de82e026a) | [34361568930](https://github.com/davidmokos/expo-drafts/actions/runs/34361568930) | [34361568990](https://github.com/davidmokos/expo-drafts/actions/runs/34361568990) |
| #5 | [01a08680-2ca8](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08680-2ca8-7f1c-97ba-4a8fbc559f56) | [34361612648](https://github.com/davidmokos/expo-drafts/actions/runs/34361612648) | [34361612790](https://github.com/davidmokos/expo-drafts/actions/runs/34361612790) |

[Catalog commit `e51ddc2`](https://github.com/davidmokos/expo-drafts/blob/e51ddc247f488170c47617e547d95e8c06ee2266/catalog.json) retained all five current previews alongside the three earlier manual entries. The manual Amber, Ocean, and Camera experiment runtimes remain incompatible with this native revision.

### Device builds for this revision

Both EAS builds finished with internal distribution for physical iOS devices. The shared build completed through [GitHub run 34361957870](https://github.com/davidmokos/expo-drafts/actions/runs/34361957870), and PR #5's separate build completed through [GitHub run 34362023030](https://github.com/davidmokos/expo-drafts/actions/runs/34362023030). Both runs succeeded. The downloaded archives' source commits and embedded native fingerprints matched their respective preview publications.

| Native build | Source commit | Embedded runtime |
| --- | --- | --- |
| [e5b1240f-1bc1-41d8-bce4-8cdd86c365a1](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/e5b1240f-1bc1-41d8-bce4-8cdd86c365a1) | [`e3d6f1e`](https://github.com/davidmokos/expo-drafts/commit/e3d6f1e83448c0f4f0ac620b52c446780807308e) | `0b52dae850fb723b136dfed86d4051693ab14617` |
| [2a21b47b-f823-4c40-b7ee-d4903bccb8c2](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/2a21b47b-f823-4c40-b7ee-d4903bccb8c2) | [`9823ade`](https://github.com/davidmokos/expo-drafts/commit/9823adebd8a8e79b7056edb502f8eaedcf775cd4) | `0d6f42d8d4867b6511c7631dfebef1a6c20ebf4f` |

Both IPAs passed strict code-signature verification, and both ad hoc provisioning profiles included the user's phone. The shared archive targets iPhone and iPad (`UIDeviceFamily` `[1, 2]`); PR #5 targets iPhone (`[1]`). Both use app version `1.0.0` and build number `1`. Their embedded bundle IDs are `29ce744f-0820-4547-9224-31c9f84cd8bc` and `381534ca-72e3-4adb-8d6a-fb1980525168`, respectively. These checks verify the artifacts and device provisioning; physical installer behavior for this revision is a separate check.

The shared archive was installed successfully on the user's iPhone with `devicectl` at 14:19 UTC on September 9. This bootstraps the new native UI without deleting app data. Phone UI automation could not start because the device was connected over Wi-Fi rather than USB; actual installation-request and first-launch UI checks on this revision are pending a wired connection.

## Earlier direct installation from the app

Commit [`cb66c6c`](https://github.com/davidmokos/expo-drafts/commit/cb66c6c) replaces the install button's website navigation with a direct handoff to the iOS installer. The shared native runtime is `166ee8786683217e3c8d06b3e8b322e68f80e17d`.

The app derives EAS's canonical manifest URL from verified project/build UUIDs. An anonymous request rejects redirects, non-success responses, data over 1 MB, a different bundle identifier, malformed software items, and insecure asset URLs. It then opens `itms-services` without retaining the temporary IPA signature. A successful URL open records no installation-complete state. The website remains an explicit fallback.

Three new native test groups passed for URL construction, manifest validation, and the bounded request lifecycle. The existing four SQLite tests, six build catalog groups, and browser/CI URL round-trip also passed. The final simulator Release binary compiled successfully and embedded the expected `166ee878…` fingerprint. Selecting Install compatible build on the simulator dismissed the action sheet and presented the device-only error while keeping Drafts Lab onscreen. Dismissing it restored the picker controls. [Package checks 34355413259](https://github.com/davidmokos/expo-drafts/actions/runs/34355413259) passed for the implementation commit.

The simulator also selected Reading List and displayed exact iOS update `01a0864e-430d-746c-9cb7-355ed62108e2` on runtime `166ee8786683217e3c8d06b3e8b322e68f80e17d`.

The five test PRs merged the implementation and republished through EAS Workflows. PRs #1–4 use the shared runtime above. PR #5 retains its iPhone-only native configuration and uses `b585b87f336c7d3a807921c6c6e80795b9fdd2e0`.

| Preview | Channel | iOS update ID |
| --- | --- | --- |
| [PR #1](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | `01a0864e-4617-7a0d-872f-9bbf0e825ce0` |
| [PR #2](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | `01a0864e-430d-746c-9cb7-355ed62108e2` |
| [PR #3](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | `01a0864e-2fb4-7a32-92a5-c9f143496736` |
| [PR #4](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | `01a0864e-4e9f-7b83-a396-423a893fb514` |
| [PR #5](https://github.com/davidmokos/expo-drafts/pull/5) | `draft-pr-5` | `01a0864e-3ef7-7a47-a63b-40e9ac66b34b` |

Both native builds completed in EAS with the `drafts-device` profile, internal distribution, and a physical iOS device target. The actual source commits and runtimes matched the requested catalog entries. The shared build was requested from PR #2 and supports PRs #1–4; PR #5 requires its separate native runtime.

| Native build | Source commit | Embedded runtime |
| --- | --- | --- |
| [f67ffd6b-8a2e-49a3-8d47-1365c5bf30ab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/f67ffd6b-8a2e-49a3-8d47-1365c5bf30ab) | [`8a32ae3`](https://github.com/davidmokos/expo-drafts/commit/8a32ae393a67fd3056e2b7a602606df723849618) | `166ee8786683217e3c8d06b3e8b322e68f80e17d` |
| [a8ca4e81-2e65-4832-9b0c-5da2d0b15df8](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/a8ca4e81-2e65-4832-9b0c-5da2d0b15df8) | [`20c574d`](https://github.com/davidmokos/expo-drafts/commit/20c574dc32ab0603351bb27558c11b97033caa45) | `b585b87f336c7d3a807921c6c6e80795b9fdd2e0` |

The shared build's first attempt failed before native compilation when Apple's Developer Portal returned an internal server error during ad hoc profile refresh. [GitHub run 34355955241, attempt 2](https://github.com/davidmokos/expo-drafts/actions/runs/34355955241/attempts/2) succeeded through [EAS Workflow 01a08657-48e7](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08657-48e7-771a-b54c-126c8e8258df). PR #5 completed through [GitHub run 34355994680](https://github.com/davidmokos/expo-drafts/actions/runs/34355994680) and [EAS Workflow 01a08650-a1be](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08650-a1be-71ee-b0c2-e897df647350). Both verified builds were published as ready in the build catalog.

Both downloaded IPAs passed `codesign --verify --deep --strict`. Their embedded `EXUpdates.bundle/fingerprint` files matched the runtimes in the table, and their ad hoc provisioning profiles included the user's phone. These checks establish artifact identity, signatures, and device provisioning.

### Physical iPhone installation

The connected iPhone 17 Pro Max running iOS 27 Beta received the new PR #5 native binary through `devicectl` once, to include the direct installer. Argent then drove the app's actual UIKit controls. The picker launched exact PR #5 EAS Update `01a0864e-3ef7-7a47-a63b-40e9ac66b34b` on runtime `b585b87f…`.

Selecting Reading List's **Install compatible build** opened the iOS confirmation dialog over the picker. It identified `api.expo.dev` and Drafts Lab, with Cancel and Install buttons. No website opened. Cancel dismissed the dialog, restored the picker controls, and retained PR #5 as the current update. Retrying showed the same system prompt.

After confirming Install, returning to the Home Screen, and reopening the app, its diagnostics showed the shared runtime `166ee8786683217e3c8d06b3e8b322e68f80e17d` and the Reading List embedded fallback. No local installation command was used for this replacement. PRs #1–4 became compatible, and PR #5 offered its matching native build.

The reverse operation also completed through the app's Install button and the iOS dialog. Reopening the app showed PR #5 runtime `b585b87f336c7d3a807921c6c6e80795b9fdd2e0` with its previously selected exact EAS Update. Both archives use app version `1.0.0` and build number `1`; same-version replacement succeeded on this device. Returning to the Home Screen was part of this test, not an assertion that iOS always requires it.

A third direct installation restored the shared build. The picker then launched Reading List EAS Update `01a0864e-430d-746c-9cb7-355ed62108e2` on runtime `166ee878…`. The phone was left on that update with the picker open: PRs #1–4 compatible, Reading List checked, and PR #5 offering **Install compatible build**. These checks verify actual native replacements and running update identities, beyond UIKit's URL-handoff callback.

## Earlier native build actions and publications

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

[PR #5, iPhone-only native preview](https://github.com/davidmokos/expo-drafts/pull/5) changes `ios.supportsTablet` from `true` to `false`. Source commit [`cb89b16`](https://github.com/davidmokos/expo-drafts/commit/cb89b161139e384c899701c878d5812eded1e8a8) therefore resolves runtime `d9c89e22141f261165d3e46ae7268a3453a1e839`. Its [publishing run 34347112985](https://github.com/davidmokos/expo-drafts/actions/runs/34347112985) succeeded, and the catalog then recorded iOS update `01a085fd-aa00-7ed2-a220-94a658f88552` in group `3e06c3bf-d848-4d3e-950f-7716c3235e9c` on `draft-pr-5`. This native configuration change made that update incompatible with the `bd60359…` build.

## Completed checks for native build actions

- Package TypeScript build, ESLint, and example TypeScript validation passed.
- All 34 Node tests passed, including build catalog validation, trusted build requests, EAS build result verification, config plugin options, and concurrent catalog publication.
- Four native transaction tests passed with real SQLite, covering rollback, cache adoption, startup recovery, and transaction ownership.
- Six Foundation build catalog test groups passed, covering exact runtime/platform/profile matching, build state ordering, project validation, verified installation URLs, encoded request bodies, and rejection of invalid GitHub request destinations.
- A request URL generated by native code round-tripped through browser query decoding and the trusted CI parser, preserving Unicode, quotes, newlines, and literal `+` characters.
- The local iOS Release app with runtime `bd60359c5e450058d8f98dbde40e5beefb68fe2e` compiled and installed on the simulator.
- The picker's Request Build action opened the browser's GitHub login handoff for the prefilled issue. This check covered opening the request page, not submitting an issue or starting a build.

## Earlier EAS request and build reuse checks

Authenticated build request [#6](https://github.com/davidmokos/expo-drafts/issues/6) used the native picker's request format. GitHub verified repository write access, the current PR #5 update and source commit, then dispatched EAS Workflows. The first attempt encountered an Apple server error while refreshing its ad hoc provisioning profile; the app displayed the failure and offered a new request.

The initial base build succeeded in EAS, but GitHub's result parser rejected an omitted simulator hint. Commit [`f610d43`](https://github.com/davidmokos/expo-drafts/commit/f610d43fcaf6f39d2637593cbc85146992aec1eb) accepts an absent workflow hint while still requiring explicit physical-device metadata from `eas build:view`. A regression fixture covers the actual EAS output. [Package checks 34348236814](https://github.com/davidmokos/expo-drafts/actions/runs/34348236814) passed.

A new request for PR #2 completed successfully in [GitHub run 34348283520](https://github.com/davidmokos/expo-drafts/actions/runs/34348283520) and [EAS Workflow 01a08608-ab03](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08608-ab03-7cd4-83d6-55caa65900bf). `get-build` reused PR #1's exact device build `163c8594-3ab2-4b7c-a120-b4be64646c7b` because the runtimes matched. The native build job was skipped. The published build catalog contained the verified ready record and canonical EAS installation link.

The PR #5 request succeeded on its second [GitHub run attempt](https://github.com/davidmokos/expo-drafts/actions/runs/34347685265/attempts/2) through [EAS Workflow 01a08608-c226](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08608-c226-7b47-b7b2-946a4b5c7034). It created device build [f4ffa64b](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/f4ffa64b-d926-4850-8834-c26271eb23bd) for the exact PR #5 source and runtime. The downloaded IPA passed strict signature verification, contained the `d9c89e…` fingerprint and iPhone-only device family `[1]`, and included the user's phone in its ad hoc profile. The build catalog's ready state appeared automatically in the visible picker. Its Install compatible build action opened the exact `f4ffa64b…` EAS page, displaying Finished and an Install button. At the end of that validation, the phone had the shared-runtime EAS build for testing the native upgrade from the picker.

## Earlier simulator and phone checks

The simulator launched PR workspace, Reading list, Focus timer, and Color studio through the native picker with runtime `bd60359c5e450058d8f98dbde40e5beefb68fe2e`. Each app displayed its exact published update ID from the earlier native build actions table. Reopening the picker marked the selected entry as current.

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

This version supports Expo SDK 57 on iOS, with a minimum deployment target of iOS 16.4. Android validation is deferred. The cache adapter depends on Expo SDK 57's database schema and requires review when upgrading Expo. App code must not start a concurrent expo-updates download or reload during a picker switch. See the README for recovery behavior and shared app data considerations.
