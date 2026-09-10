# iOS validation, September 8–10, 2026

This record covers the native example app and its PR previews, and preserves validation results for earlier runtime revisions. Local simulator validation uses an iPhone 17 Pro Max running iOS 26.3. Native apps are compiled in Release mode with Xcode, and EAS hosts the remote updates.

The app uses Expo SDK 57, React Native 0.86.3, and expo-updates 57.0.21. Its EAS project is [@mokosdavid/expo-drafts-lab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab), and its bundle identifier is `dev.davidmokos.draftslab`.

## Automatic native builds and installation resume

Commit [`95e9161`](https://github.com/davidmokos/expo-drafts/commit/95e91612963efbf873d7a83219b851dc3d276f7b) adds an independent native-build trigger after successful same-repository PR publication. GitHub verifies the exact publication against its own run metadata and EAS, then serializes native lookup and creation by project, platform, profile, and runtime. The app saves the selected update UUID and channel before opening the iOS installer and resumes it after the matching native build starts.

The package build, lint, example typecheck, all 52 Node tests, and the native suites passed locally and in [main CI](https://github.com/davidmokos/expo-drafts/actions/runs/34412742179). The 13 installation-state test groups include persistence across an actual separate-process exit, exact identity completion, interrupted attempts, legacy records, expiration, and stale callback protection. The final Release simulator app compiled with native runtime `4350b5d2dffa870ff3ef708c18cb8e618b434221`.

The lifecycle test used two separately compiled Release simulator fixtures with explicit runtime overrides for the already-published shared and PR #5 updates. The source fixture retained its pending request across a cold restart without opening an incompatible update. Replacing it with the target fixture without uninstalling automatically opened PR #5's exact remote UUID `01a0876c-3362-72c4-b190-878afb9f2f75` at runtime `7997c404992219f159f865969505cb9be91ad59d`. The native Running details confirmed both values, the saved request was cleared, and a subsequent cold restart kept that update without replaying the installation request. These fixtures test lifecycle and persistence; their overridden runtimes do not establish real native compatibility.

An interrupted-attempt fixture stayed on the bundled version and offered **Open Selected Draft** without automatically retrying. That explicit action opened the exact remote update and cleared the request. A stale UUID instead produced the changed-publication error and retained a retry state while Running stayed on the embedded UUID. Signing out removed both the saved request and EAS rows.

The final app also passed checks without a runtime override. Its picker opened the freshly published Color Studio update `01a08850-f733-760f-a2b9-cbe4bfa4fa9a` at runtime `4350b5d2dffa870ff3ef708c18cb8e618b434221`, with source `d3491b6f0c9fd621cd6235c2d7ec594916ef0cf5`. **Run bundled version** returned to the exact embedded UUID `21f99094-9909-42e3-93c9-6aec1f8f2bb4`. Sign Out removed all EAS rows and the temporary QA Keychain session. Simulator automation servers were stopped after testing. The QA session fixture does not establish a fresh browser sign-in callback.

The new source build must be installed once before this handoff can work. Older source builds did not save an exact publication ID and their existing installation records remain status-only.

### Verified publications and native builds

All five PR publication workflows and package checks passed. Their saved reports match the authenticated EAS workflow outputs and each channel's latest iOS update. PRs #1–4 use runtime `4350b5d2dffa870ff3ef708c18cb8e618b434221`; PR #5 preserves `ios.supportsTablet: false` and uses `e31bf44a823d6aaf1538d5c26cff659b10e562cb`. A stale local Expo installation in PR #2 was corrected with locked dependency installation before publication; no native input or runtime policy was changed.

| PR | Source | Exact iOS update | Successful CI |
| --- | --- | --- | --- |
| [#1](https://github.com/davidmokos/expo-drafts/pull/1) | [`9de0ec6`](https://github.com/davidmokos/expo-drafts/commit/9de0ec6c0e2fe5b0797a5f0c24cdd749ae2813a1) | `01a08852-6d90-701f-8406-aa2afbdba802` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08851-2372-7330-84dc-180f73bd403b) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34413014348) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34413014335) |
| [#2](https://github.com/davidmokos/expo-drafts/pull/2) | [`aebb188`](https://github.com/davidmokos/expo-drafts/commit/aebb188bd0207ce1c355448307520f3310c7997a) | `01a08857-1593-72be-8412-80c5760c683d` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08855-c503-72e0-b33e-9adae981786e) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34413390074) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34413389794) |
| [#3](https://github.com/davidmokos/expo-drafts/pull/3) | [`64e24ed`](https://github.com/davidmokos/expo-drafts/commit/64e24ed07abe71f3e03607ae1a5f8af0365aeda3) | `01a08852-9d1d-78d5-9bbd-25df39064a39` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08851-562f-7312-99a7-346cb9c8a3a1) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34413014879) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34413014856) |
| [#4](https://github.com/davidmokos/expo-drafts/pull/4) | [`d3491b6`](https://github.com/davidmokos/expo-drafts/commit/d3491b6f0c9fd621cd6235c2d7ec594916ef0cf5) | `01a08850-f733-760f-a2b9-cbe4bfa4fa9a` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0884f-b393-7625-80d1-64aa8c79ff2d) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34412875938) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34412875935) |
| [#5](https://github.com/davidmokos/expo-drafts/pull/5) | [`fb2893e`](https://github.com/davidmokos/expo-drafts/commit/fb2893eccc64a0cf06982ef502942a815747a3e3) | `01a08850-eb1d-72e3-9c18-360edf5c3f8f` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0884f-b0a4-73d1-aa31-7aca128efb68) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34412881729) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34412881671) |

Successful publication automatically started two native builds. Both EAS lookup jobs found no existing match and the build jobs created exactly one binary per new runtime. No manual native workflow was dispatched. Both signed archives passed strict signature verification, native fingerprint and source checks, and framework dependency verification. Each includes the registered phone and a valid profile expiring July 3, 2027; each contains nine Mach-O images with all 29 required archive dependencies.

| Native build | Source | Embedded update | Successful CI |
| --- | --- | --- | --- |
| [Shared, PRs #1–4](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/594833ee-f1e8-47fd-8e2a-2979dcd5c509) | `d3491b6` | `875dcac7-67b2-4fca-8618-f2a02dc173d8` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08852-7bd3-7817-9d12-ddf35a978ac9) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34413094109) |
| [PR #5, iPhone only](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/9c94f40a-1ac3-40ca-88f6-d2f02086a9be) | `fb2893e` | `c7c4f115-066b-45a6-9241-a23c0565a7fc` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08852-79d1-74ef-a407-4ba8c62b01c6) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34413104273) |

The later [PR #2 automatic request](https://github.com/davidmokos/expo-drafts/actions/runs/34413620670) succeeded. Its [EAS workflow](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08858-8110-77c6-ae6f-45f516683acb) returned the existing shared build from `GET_BUILD` and skipped `BUILD`. The reused binary correctly retains PR #4's source commit while matching PR #2's native runtime. Earlier PR #1/#3 pending requests were coalesced by GitHub concurrency; they did not cancel the running build or dispatch extra binaries.

The verified shared build `594833ee-f1e8-47fd-8e2a-2979dcd5c509` was installed successfully on the registered iPhone without uninstalling the app. The attempted launch was denied because the phone was locked. Physical launch and the system-installer handoff to PR #5 remain for the user to try after unlocking; simulator resume checks do not claim a completed physical OTA installation.

## Publication order and timestamps

Commit [`38a6cf2`](https://github.com/davidmokos/expo-drafts/commit/38a6cf2227bfb7f6c8c229bebf97e27eaf06155b) sorts the latest iOS update on each channel by its actual publication instant, newest first. Cached catalogs and refreshed EAS responses use the same comparison. Equal timestamps use channel and ID to keep the order stable. Each native row includes its localized publication date and time, including seconds, alongside the channel or build status and in its accessibility label. Invalid dates from a custom catalog appear last with an unavailable-time label; EAS responses still reject invalid publication dates.

All 42 Node tests, the native Swift suites, the Release simulator build, and [main CI](https://github.com/davidmokos/expo-drafts/actions/runs/34388574703) passed. Six catalog test groups cover offsets, fractional seconds, equal-time ties, invalid custom dates, and independence from names or native compatibility. An EAS regression checks ordering across response pages. The shared simulator runtime is `8a743208811cf520fdd423e4678b2ea15d332b7b`.

The simulator picker showed local UTC+02:00 publication times, including seconds, on long titles and incompatible rows without clipping. Pull to refresh preserved the same actual-time order. After all five automatic PR publications completed, their native row labels matched the exact EAS publication times in Europe/Warsaw. The refreshed order was PR #4, #5, #2, #1, #3. Color Studio and Reading List both launched over EAS Update; selecting Reading List kept it in third position. Returning to the embedded bundle restored `2eac964c-5886-4500-87b7-2248fdf1d4af`. This used the existing QA-only Expo Keychain fixture; it does not establish a new browser sign-in test.

The user's September 9 screenshot shows the previous shared build's bundled ID `f49fe983` running on their phone. Its order was already correct for those EAS publications: Reading List at 17:46:47 UTC, then PR Library at 17:44:45, iPhone-only at 17:44:39, Color Studio at 17:44:36, and Focus Timer at 17:44:34. The new comparison fixes timestamp-format edge cases; it does not sort by PR number.

All five PR publication workflows and checks succeeded at these source commits; live EAS reads verified the channel, exact update, runtime, and source. PRs #1–4 share `8a743208811cf520fdd423e4678b2ea15d332b7b`; PR #5 retains its iPhone-only runtime `7997c404992219f159f865969505cb9be91ad59d`.

| PR | Channel | Source | iOS update ID | Workflow |
| --- | --- | --- | --- | --- |
| [#1](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | [`298e58a`](https://github.com/davidmokos/expo-drafts/commit/298e58af0f27fc78b8fd83efa02580e78fee4cc2) | `01a0876b-f1dc-795e-a7fd-a5247116e9d7` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876a-87a6-728d-85fc-5901dbb792cf) |
| [#2](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | [`92121ec`](https://github.com/davidmokos/expo-drafts/commit/92121ecb0403922dc73bd892306381f73debd596) | `01a0876c-09c4-7ecf-ae27-6c53c1071c55` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876a-a50e-7ae4-b6e9-7cb129daabfc) |
| [#3](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | [`3b24243`](https://github.com/davidmokos/expo-drafts/commit/3b242438f696f4f5e4953a517cce1d6a2b52cbea) | `01a0876b-e6e0-7828-b074-0f25b67dc5ec` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876a-7e33-7b3e-a7f2-bd4fd63e9adb) |
| [#4](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | [`55f735f`](https://github.com/davidmokos/expo-drafts/commit/55f735fa44b378605cc35aa7a7bb0ec03c540fcf) | `01a0876c-49c3-7f51-b592-f9c6614ee7d8` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876a-ea7e-70d4-bc7d-ba2d5bb598aa) |
| [#5](https://github.com/davidmokos/expo-drafts/pull/5) | `draft-pr-5` | [`a804504`](https://github.com/davidmokos/expo-drafts/commit/a8045044f430586d282c5afb77c5e24c6d437d9f) | `01a0876c-3362-72c4-b190-878afb9f2f75` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876a-d8e0-7986-9bc7-b7cf4043b87c) |

Both replacement device builds succeeded with the existing ad hoc profile (`refresh_ad_hoc_provisioning_profile: false`). Downloaded archives passed strict signature verification, exact source and runtime checks, registered-phone provisioning, callback configuration, and all 29 framework dependencies across nine Mach-O images.

| Native build | Embedded update | Successful CI |
| --- | --- | --- |
| [Shared, PRs #1–4](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/a322d923-e00e-436f-a988-bebfb0a8017b) | `d7bda380-87b0-4f34-a58b-1bc7f538cc05` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876e-8929-7c5b-bbed-1eb5a050a295) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34389193188) |
| [PR #5, iPhone only](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/45a09066-23e3-43ac-9972-0c39913b4859) | `99d8c0fe-4c3a-40e8-8302-0932fcb610a8` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a0876e-23cc-7fc7-bb68-77ad4ae370eb) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34389137908) |

The verified shared archive was installed successfully over USB on the user's iPhone and launched as process `23832`. The install retained the existing app data. Device UI interaction was not repeated; timestamp rendering, chronology after refresh and selection, and switching were tested on the simulator. The temporary simulator account was signed out and its automation servers stopped after testing.

## Native example app and PR previews

Commit [`67f4767`](https://github.com/davidmokos/expo-drafts/commit/67f47679aeeb604309960667d8643e10ee01444f) replaces the example's single-screen demos with four native tabs: Library, Focus, Studio, and Settings. Expo Router supplies the tab bar and navigation headers. `@expo/ui` supplies the forms and controls, including the iOS color picker. Every preview keeps all four screens; `example/src/data/preview.ts` selects its initial tab, content, colors, and timer defaults.

The package build, lint, all 42 Node tests, native suites, example typecheck, and managed iOS runtime check passed in [main CI](https://github.com/davidmokos/expo-drafts/actions/runs/34384283237). The shared runtime for PRs #1 through #4 is `672192333636b1034ed4a1ed4388ee8b0d12d87c`. PR #5 preserves `ios.supportsTablet: false` and uses `b2f0eb732231e1534c0d4e1e3dccc8b3da61ee9b`.

### Release simulator checks

The local Release app compiled and opened all four native tabs. Library checks covered changing a favorite, marking a book finished, and applying the shared library filters from Settings. The Focus timer started at `25:00`, continued across tab changes, and paused at `23:49`. Studio checks covered choosing green with the native color picker, changing lightness, and resetting the color. Tab changes retained screen state.

The native draft picker launched live EAS updates in this order: Color Studio, Focus Timer, then Reading List. Each opened its configured initial tab with the expected preview content. Settings > Build details showed Reading List's actual update UUID `01a08747-8a57-7765-bdc9-df47563b4fcd` and source `EAS Update`. **Run bundled version** returned to the simulator's exact embedded UUID `46d7ac54-7b04-4061-a585-9d6b3e0083e3`; that selection persisted after a cold restart. The fourth compatible PR then opened PR Library with its purple accent. Settings' Browse drafts action opened the same native picker. The iPhone-only row changed from **Build in progress** to **Install compatible build** when EAS finished, and its action explained that device builds cannot be installed in the simulator. Sign Out removed the temporary simulator session and draft rows after validation.

These checks reused the local QA-only Keychain session fixture and cached native build artifacts described in the EAS discovery record below. They do not establish completion of a real Expo browser sign-in callback. Light appearance was visually verified. Dark appearance remains unverified: after requesting dark mode in the simulator, the app's scene and window still reported inherited light traits, with no window or root-controller appearance override.

### Verified publications

All five PR publication workflows and package checks passed at the source commits below. Authenticated EAS reads matched each report's latest channel publication, exact iOS update ID, source commit, runtime, and successful EAS workflow. The app reads these previews directly from EAS.

| Preview | Channel | Source | iOS update ID | Successful CI |
| --- | --- | --- | --- | --- |
| [PR #1](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | [`1d07f4e`](https://github.com/davidmokos/expo-drafts/commit/1d07f4e50df0507b8104c102c6b528bbba51cfb3) | `01a08745-aae5-7658-9b01-f5a8a94e06c9` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08744-2727-7389-99eb-8bc9deb15d9b) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34384510511) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34384510505) |
| [PR #2](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | [`53d6a8d`](https://github.com/davidmokos/expo-drafts/commit/53d6a8d92271a7194bd5a706f33bad51c8e9b5c3) | `01a08747-8a57-7765-bdc9-df47563b4fcd` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08746-1531-7bab-9e97-56b8b8a57b81) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34384707781) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34384707835) |
| [PR #3](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | [`aa883b5`](https://github.com/davidmokos/expo-drafts/commit/aa883b54858d2f3f3428bab181fdd4aa8c9706b5) | `01a08745-839f-7569-9f4a-2b03f221fcf4` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08744-1b86-7bb0-b4ec-ce67d5be9064) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34384505642) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34384505630) |
| [PR #4](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | [`d86dcab`](https://github.com/davidmokos/expo-drafts/commit/d86dcabe9eb76d03ebdc93034ce103b66421d937) | `01a08745-8ab8-7534-8e87-395ba8ddd362` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08744-33a0-772f-b0a9-3177d58f8acd) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34384499874) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34384499835) |
| [PR #5](https://github.com/davidmokos/expo-drafts/pull/5) | `draft-pr-5` | [`fc74d5e`](https://github.com/davidmokos/expo-drafts/commit/fc74d5efa089d16f81db652996568a5b545c5a21) | `01a08745-9688-71fa-8194-6862d495031e` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08744-4a67-71a2-9502-42361110f86a) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34384514440) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34384514405) |

### Device builds

Both EAS builds and their GitHub workflows succeeded on the first attempt. They reused the existing valid ad hoc profile with `refresh_ad_hoc_provisioning_profile: false`.

| Native build | Source | Embedded update | Successful CI |
| --- | --- | --- | --- |
| [Shared, PRs #1–4](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/3a00bbb5-ca54-4bcc-a6c9-798732803aa2) | [`53d6a8d`](https://github.com/davidmokos/expo-drafts/commit/53d6a8d92271a7194bd5a706f33bad51c8e9b5c3) | `f49fe983-f286-413d-871e-8639cce0aedd` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08749-ca99-781a-8cf1-91d18ae1844d) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34385106867) |
| [PR #5, iPhone only](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/33285ce2-5306-4b4a-963d-81e1f3a1d8ff) | [`fc74d5e`](https://github.com/davidmokos/expo-drafts/commit/fc74d5efa089d16f81db652996568a5b545c5a21) | `8cf20813-0540-4841-9875-cabbc7a9b15d` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08747-fb95-742c-9bee-7dfc73138552) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34384923093) |

Downloaded archives passed strict signature checks, exact source and embedded runtime checks, registered phone provisioning, project/callback configuration, and complete framework dependency checks. Each contains nine Mach-O images and 29 resolved archive dependencies. The shared build targets iPhone and iPad; PR #5 targets iPhone only. Both use version `1.0.0`, build `1`, and direct EAS discovery. The shared build embeds Reading List as its bundled fallback.

A local installation of the verified shared build was attempted at 17:57 UTC. The phone became reachable over a wired CoreDevice tunnel with Developer Mode enabled, but iOS rejected the install with `IXRemoteErrorDomain` code `9`: “Installation on this device is prohibited by ManagedConfiguration.” The new build was not installed. The source of the phone restriction is not yet confirmed; the user was asked to check its app-installation settings. Physical launch, browser sign-in, and switching on this new phone build remain pending.

## Earlier direct EAS discovery

Commit [`1e4c6f8`](https://github.com/davidmokos/expo-drafts/commit/1e4c6f87664948b58d959659aeda845b15d61a6e) replaces the example app's GitHub catalog with authenticated EAS discovery. The native picker reads channel names, latest iOS publications, exact update IDs, source commits, and runtimes from EAS GraphQL. Device builds come from the same authenticated API. GitHub remains the optional build-request dispatcher and PR publication trigger.

Expo sign-in uses the system authentication browser and a project-specific callback with a random nonce. The app verifies the returned session with EAS before storing it in Keychain. No publishing token is embedded in the binary. Sign-out cancels pending requests and clears the session and lists; losing project access clears project data without treating a valid Expo login as expired.

The shared runtime is `fe37c66b8936ffb353b2bee9cf9180cb0f658c9b`. PR #5 preserves its iPhone-only native configuration and uses `cdbb38c4fa4a439071aa563f771bea853e934371`.

All 41 Node tests, TypeScript builds, lint, and example typecheck passed for the discovery implementation. The manual profile-refresh option added one test, bringing the passing total to 42. All native suites passed, including eight new EAS discovery groups covering channel routing, incompatible runtimes, build identity and expiry, pagination, request cancellation, transport limits, authentication errors, and shared Retry-After backoff. [GitHub checks](https://github.com/davidmokos/expo-drafts/actions/runs/34379123369) passed for the implementation commit.

A standalone invocation of the actual Swift client authenticated with the existing local Expo session and returned all eight published previews and eight device builds. The latest five PR update identities and both previous verified device archives matched EAS metadata. This check preceded the publications listed below.

### Simulator checks

The Release simulator app opened the official Expo sign-in page in the system browser. Cancel restored the native Sign in row without an error. Authenticated UI testing used the existing local Expo session inserted into only this simulator app's Keychain with LLDB. This verifies authenticated discovery and session persistence; it does not claim completion of a real browser login callback.

The simulator build embeds UUID `9b184ebc-0876-4ab8-8080-6b63bd59fd9a`. The signed-in picker listed all eight channels, showed compatible PRs #1–4, and kept PR #5 visibly incompatible. It launched PR #1 update `01a08715-b9cb-71af-aea1-ee6a47ac03c8`. **Run bundled version** returned to the exact embedded UUID and remained selected after a cold restart. The saved Expo session also survived that restart. The picker then launched Reading List update `01a08718-5b55-7c67-8e8b-055a9fad478d`, and Running showed that exact ID and native runtime.

The account button's **Sign Out** cleared the draft rows while preserving the truthful Running section. Another cold restart remained signed out. The session was restored through the same local QA fixture for the remaining update and build-discovery checks.

Local build infrastructure required two QA-only repairs. Maven's local edge refused React Native 0.86.3 artifacts, so CocoaPods used cached Release archives whose SHA-256 hashes matched the official Maven metadata. Simulator Keychain access required simulated entitlements embedded by a relink of the existing app objects. Neither repair changed package source, runtime inputs, or bundled resources. A dependency check verified every nested Mach-O load; a temporary copy with React.framework removed correctly failed on the missing dependency.

The shared build's first two attempts failed before native compilation because Apple returned an Internal Server Error during forced profile refresh. Commit [`6a4f562`](https://github.com/davidmokos/expo-drafts/commit/6a4f5628256aa474c16d99c28c4e0a897141bacc) adds a manual option to reuse existing profiles, while preserving automatic refresh by default and for issue requests. The assigned EAS ad hoc profile was active, matched the previous successful archive, included the target phone, and was valid through July 3, 2027. This workflow change does not alter the native runtime.

### Publications for EAS discovery

All five PR publication workflows and package checks passed. Authenticated EAS reads verified each latest iOS update against the publication report, exact PR head, channel mapping, and successful EAS workflow. No GitHub catalog was written or read by the app.

| Preview | Channel | Source | iOS update ID | Successful CI |
| --- | --- | --- | --- | --- |
| [PR #1](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | [`ee5dd0d`](https://github.com/davidmokos/expo-drafts/commit/ee5dd0d01bf00d93ff574b3bc4109d63abd0a2c9) | `01a08715-b9cb-71af-aea1-ee6a47ac03c8` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08714-7e91-7b47-968a-47e31ee4f245) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34379188397) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34379188559) |
| [PR #2](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | [`bbcec14`](https://github.com/davidmokos/expo-drafts/commit/bbcec144e6b761d83726ba168b738d7af133ec32) | `01a08718-5b55-7c67-8e8b-055a9fad478d` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08717-3f07-70a3-afa2-b22c95606dfb) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34379507173) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34379507151) |
| [PR #3](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | [`31b70ae`](https://github.com/davidmokos/expo-drafts/commit/31b70ae1f47be1bf6647b7cefcdb56d963bf3e72) | `01a08718-709e-7320-a181-353f51c5264a` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08717-4679-77ca-a2a9-f98a613deee4) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34379507080) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34379507057) |
| [PR #4](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | [`5d875cd`](https://github.com/davidmokos/expo-drafts/commit/5d875cd187ef65b68e4f86afff3801653c96dfd0) | `01a08718-7201-7c1f-9eb1-ce1cb3ba488a` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08717-4f6e-7ad2-b7fe-8693c097c3e4) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34379510662) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34379510807) |
| [PR #5](https://github.com/davidmokos/expo-drafts/pull/5) | `draft-pr-5` | [`83f89e4`](https://github.com/davidmokos/expo-drafts/commit/83f89e4d55a82879b7ded338c710c9f498bd7735) | `01a08715-d906-77b2-aed1-3fc3955c2ca3` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08714-a103-712a-a512-3d261411940e) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34379197576) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34379197534) |

### Verified device builds for EAS discovery

Both EAS workflows and their final GitHub runs succeeded. The shared build reused the verified existing profile after the Apple failures; the iPhone-only build succeeded on its second normal attempt with profile refresh enabled. The final workflow option also passed [package checks](https://github.com/davidmokos/expo-drafts/actions/runs/34380963324).

| Native build | Source | Embedded update | Successful CI |
| --- | --- | --- | --- |
| [Shared, PRs #1–4](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/adebb332-c1bb-44ad-9901-0546beb9ca77) | [`bbcec14`](https://github.com/davidmokos/expo-drafts/commit/bbcec144e6b761d83726ba168b738d7af133ec32) | `095600b8-7cd3-4860-a7c5-1fd6d82f1011` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08724-e130-7a23-a044-41b585d0606f) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34381012813) |
| [iPhone only, PR #5](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/e64bf082-b9fa-49c6-bfa0-33f43f17570a) | [`83f89e4`](https://github.com/davidmokos/expo-drafts/commit/83f89e4d55a82879b7ded338c710c9f498bd7735) | `ea595220-cf91-4f11-bddb-acd3f8773c37` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a08720-11b5-7013-9fb4-db4fa81644ad) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34379828921/attempts/2) |

Both downloaded IPAs passed strict deep signature verification, include the registered phone, and embed the expected native fingerprints. The shared build supports iPhone and iPad; PR #5 supports iPhone only. Both have empty custom catalog URLs, the correct EAS project and registered Expo sign-in callback, and complete framework dependencies. Each archive contained nine Mach-O images and all 29 required dependencies within the app. Both use app version `1.0.0` and build number `1`.

The simulator's native picker fetched the live iPhone-only build from EAS, showed **Build in progress**, and then changed to **Install compatible build** after it finished. The ready action correctly explained that device builds must be installed on a registered physical device. The temporary simulator Expo session was removed through Sign Out after validation.

Physical installation of these new builds is pending. The phone was still disconnected when the archives were ready; its device tunnel was unavailable, with the last recorded connection at 15:44 UTC on September 9. No new archive was installed on the phone in this validation. The previously installed build continues to use the earlier GitHub discovery until replaced. The new build requires Expo sign-in in the picker; real browser authentication and switching on the physical phone remain to be verified.

## Earlier return to the bundled version

Commit [`ad23424`](https://github.com/davidmokos/expo-drafts/commit/ad234246f57dd0018655b971701ebb3f0fd568c0) adds **Run bundled version** below Running while a downloaded bundle is active. It restores the installed native build's original update headers, prepares the exact embedded UUID locally, and verifies the launched identity before committing. It does not require a catalog entry or a download. A failed selection restores the previous headers and cache metadata; an interrupted selection uses the existing startup recovery transaction.

The final native implementation is [`97e6f03`](https://github.com/davidmokos/expo-drafts/commit/97e6f03026b9e105546a73a98998b9684251c936), which binds the embedded row and clears server metadata in one SQLite transaction. Its shared iOS runtime is `8bc256182be4455e53cb429fb3771559e0ee5a7c`; PR #5 uses `dc86b332558e23da1051e6bed8d39016ef2f9e60`. The Release simulator archive compiled successfully with embedded UUID `008b90ef-c78d-4a72-b7f9-945b847f03d5`.

TypeScript builds, lint, example typecheck, all 34 Node tests, and all native test suites passed. The 11 transaction groups execute against real SQLite and the installed Expo SDK 57 launcher and loader policies. They cover stale metadata, exact embedded identity, database reopening, returning to a published update older than the native build, wrong identities, failed selection, missing embedded rows, inherited headers, and interrupted recovery. A negative control removes the atomic binding from a temporary source copy and correctly fails the regression test. No production source was altered by that control.

On the final Release simulator build, the picker launched Reading List update `01a086c9-f860-71cf-926a-7389ab3ae681`. **Run bundled version** returned to the original embedded UI and exact UUID `008b90ef-c78d-4a72-b7f9-945b847f03d5`. A cold restart retained that embedded selection. Running correctly identified the bundled source, and the return action was hidden while it was already active. The picker then successfully launched Color Studio update `01a086ca-351c-7c8e-87dc-626048166cf8`.

A separate simulator fixture removed only that exact embedded cache row while Color Studio was active, after saving a database backup. Returning through the same UI restored the signed embedded bundle's cache row and launched its exact UUID. It remained selected after another cold restart, and the settled preferences contained no pending selection transaction. This explicitly exercises cache recovery; it does not claim a naturally occurring eviction or modify phone data.

### Final publications for Run bundled version

All five PR branches merged native implementation [`97e6f03`](https://github.com/davidmokos/expo-drafts/commit/97e6f03026b9e105546a73a98998b9684251c936) and republished successfully. The EAS outputs, GitHub artifacts, and catalog agree on each exact iOS update ID, source commit, group, and runtime. PRs #1–4 use `8bc256182be4455e53cb429fb3771559e0ee5a7c`; PR #5 preserves `ios.supportsTablet: false` and uses `dc86b332558e23da1051e6bed8d39016ef2f9e60`.

| Preview | Channel | Source | iOS update ID | Successful CI |
| --- | --- | --- | --- | --- |
| [PR #1: [example] previews a pull request from GitHub Actions](https://github.com/davidmokos/expo-drafts/pull/1) | `draft-pr-1` | [`e55454b`](https://github.com/davidmokos/expo-drafts/commit/e55454b55248556fd2a49972a2fd4204d105ff51) | `01a086ca-5067-7448-958f-7bebb01f5835` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086c9-3005-7f0f-b1a9-b58d65e4a437) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34370397806) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34370397627) |
| [PR #2: [example] Reading list](https://github.com/davidmokos/expo-drafts/pull/2) | `draft-pr-2` | [`a46f493`](https://github.com/davidmokos/expo-drafts/commit/a46f4933bc1486d4685f8b18e2eeddc20f5efcdc) | `01a086c9-f860-71cf-926a-7389ab3ae681` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086c8-e5e3-7491-8929-8456a1fb4556) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34370367302) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34370367212) |
| [PR #3: [example] Focus timer](https://github.com/davidmokos/expo-drafts/pull/3) | `draft-pr-3` | [`3b3e86e`](https://github.com/davidmokos/expo-drafts/commit/3b3e86e3704e2cc7615bc24abc6007f7057718b5) | `01a086ca-2ba9-7cc0-aab5-e370c8d49ed8` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086c9-157c-7853-aff1-f6deeb929e51) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34370377003) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34370377173) |
| [PR #4: [example] Color studio](https://github.com/davidmokos/expo-drafts/pull/4) | `draft-pr-4` | [`9f45b10`](https://github.com/davidmokos/expo-drafts/commit/9f45b10d71bed3dddc26ccfd4accf1c3e4786631) | `01a086ca-351c-7c8e-87dc-626048166cf8` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086c9-1464-7834-829d-c3e16e9f7ab6) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34370369133) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34370369223) |
| [PR #5: [example] iPhone-only native preview](https://github.com/davidmokos/expo-drafts/pull/5) | `draft-pr-5` | [`2e16f36`](https://github.com/davidmokos/expo-drafts/commit/2e16f36b068435fdb92e8e4fb4145532d60404b4) | `01a086ca-4cbd-762f-af74-4887556d590f` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086c9-26cb-7c38-acf0-13ed7469d626) · [publish](https://github.com/davidmokos/expo-drafts/actions/runs/34370393220) · [checks](https://github.com/davidmokos/expo-drafts/actions/runs/34370394833) |

[Catalog commit `058970d`](https://github.com/davidmokos/expo-drafts/blob/058970deae5fd7195184c104c7300bc154ed48fc/catalog.json) contains all five final previews and retains the earlier Amber, Ocean, and Camera entries with their actual incompatible runtimes.

### Final device builds

Both EAS workflows and GitHub native-build runs succeeded. Both builds use the `drafts-device` profile, internal distribution, and a physical iOS device target. Their verified ready catalog records match the requested native fingerprints and exact source commits.

| Native build | Source | Embedded runtime | Successful CI |
| --- | --- | --- | --- |
| [Shared (PRs #1–4): `9e4362c2-76f8-4170-aaf4-f9c5978f29a7`](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/9e4362c2-76f8-4170-aaf4-f9c5978f29a7) | [`a46f493`](https://github.com/davidmokos/expo-drafts/commit/a46f4933bc1486d4685f8b18e2eeddc20f5efcdc) | `8bc256182be4455e53cb429fb3771559e0ee5a7c` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086cc-a782-7d7e-bdf3-ad8f2984e00a) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34370783652) |
| [PR #5 (iPhone only): `b6eb5613-280a-45d0-9bcb-283062ca211a`](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds/b6eb5613-280a-45d0-9bcb-283062ca211a) | [`2e16f36`](https://github.com/davidmokos/expo-drafts/commit/2e16f36b068435fdb92e8e4fb4145532d60404b4) | `dc86b332558e23da1051e6bed8d39016ef2f9e60` | [EAS](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/workflows/01a086cd-6f73-78f5-9820-9c509d7c0e23) · [GitHub](https://github.com/davidmokos/expo-drafts/actions/runs/34370886497) |

Both downloaded IPAs passed strict signature verification and include the user's phone in their ad hoc profiles. The shared build targets iPhone and iPad (`UIDeviceFamily` `[1, 2]`) and embeds bundle `5e68c556-5b06-41b9-ae6d-40cfae6117fa`. PR #5 targets iPhone (`[1]`) and embeds bundle `5d2e9970-9619-4f79-9a60-485a00dbc8d8`. Both use app version `1.0.0` and build number `1`. These results verify archive identity and provisioning; physical installation and in-app switching are recorded separately.

The final shared archive was installed successfully on the user's iPhone through `devicectl` at 15:43 UTC on September 9, without uninstalling the app or deleting its data. UI validation of the new return action on this phone is pending: Xcode reported that the device was locked, and the user was asked to unlock it. The successful return and cold-restart checks above were performed on the simulator.

## Earlier installation request and Running UI

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

The shared archive was installed successfully on the user's iPhone with `devicectl` at 14:19 UTC on September 9 without deleting app data. After a USB connection became available, actual phone UI checks finished at 15:16 UTC. The initial Running row identified embedded UUID `29ce744f-0820-4547-9224-31c9f84cd8bc` on runtime `0b52dae8…`.

The real iOS installation prompt was canceled once. Installation requested remained visible with its activity indicator and Home Screen instruction, survived closing and reopening the picker and restarting the app, and disappeared after Hide Status. Running continued to identify the original bundle. No fixture was used on the phone.

A second real installer request was confirmed, followed by Home and a 42-second wait. Reopening the app showed runtime `0d6f42d8d4867b6511c7631dfebef1a6c20ebf4f`, cleared Installation requested, and restored already cached PR #5 EAS Update `01a08681-45fd-7294-85ed-926593be7598`. The Running details and PR checkmark matched that identity. No additional local installation command was used for this replacement. The upgrade restored an EAS Update immediately, so an embedded first launch after that replacement is not claimed.

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
