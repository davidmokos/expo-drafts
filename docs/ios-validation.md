# iOS validation — September 8, 2026

The package and Drafts Lab were compiled in Release mode and tested on an iPhone 17 Pro Max simulator running iOS 26.3. No Metro server was running while the app selected, downloaded, or launched updates. The native build was compiled locally with Xcode; EAS hosted the actual remote updates.

The app uses Expo SDK 57, React Native 0.86.3, and expo-updates 57.0.21. Its EAS project is [@mokosdavid/expo-drafts-lab](https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab), and its bundle identifier is `dev.davidmokos.draftslab`.

## Published test updates

The installed native runtime is `49c985303fd99723dc5d59a62ef5e31c1c34d457`.

| Draft | Channel | iOS update ID | Compatibility |
| --- | --- | --- | --- |
| Amber workspace | `draft-amber` | `01a0828a-57c7-7575-b5f1-bb2b6823bcaf` | Matches installed runtime |
| Ocean workspace | `draft-ocean` | `01a0828a-9e45-792b-a6af-7a7d58c7110d` | Matches installed runtime |
| Camera experiment | `draft-native` | `01a0827b-f2be-7704-9101-52d0e7c2b195` | Deliberate mismatch: `drafts-lab-native-v2` |

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

## Automated checks

- Package TypeScript build and ESLint passed.
- Example TypeScript validation and Expo dependency alignment passed.
- Ten Node tests passed, covering the config plugin, catalog validation, and concurrent catalog publishers using a real bare Git repository.
- Four native transaction tests passed using the production Swift cache adapter, real SQLite, and an EXUpdates test double. They exercise stale-fetch rollback, cached update adoption, interrupted-selection recovery, and transaction ownership.
- The complete iOS Release app compiled and installed successfully against the real Expo native modules.
- [GitHub Actions run 34270412779](https://github.com/davidmokos/expo-drafts/actions/runs/34270412779) passed both the package checks and macOS transaction tests for implementation commit `3f528cf`.
- `npm pack` succeeded with generated Android build files excluded.

## Remaining setup and limits

The per-PR GitHub workflow is committed. Its `EXPO_TOKEN` secret still needs to be configured before CI can publish EAS Updates. Remote publication was validated using the local Expo login, followed by the same catalog CLI and Git publisher used by the workflow; automatic PR publication has not yet run.

This version supports iOS SDK 57 only. Android validation is deferred. The cache adapter depends on Expo SDK 57's database schema and requires review when upgrading Expo. App code must not start a concurrent expo-updates download or reload during a picker switch. See the README for recovery behavior and shared app data considerations.
