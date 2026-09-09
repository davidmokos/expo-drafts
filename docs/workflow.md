# Publishing PR drafts

Each pull request gets an EAS channel such as `draft-pr-42`. The workflow publishes the PR title as the EAS Update message, which the picker uses as its name. Another push publishes a new update on that channel. EAS is the source of truth: the app signs in to Expo and reads channels and their latest iOS updates directly. No GitHub JSON hosting or publisher token in the app is required.

The picker reads the latest update without filtering by the installed runtime. This keeps a PR with native changes visible as incompatible instead of silently substituting an older compatible update. Before downloading, it compares the selected runtime with the native build. After fetching, it verifies the exact manifest update ID. If another agent published meanwhile, refresh the picker before trying again.

The supplied workflow uses ordinary channels that route to one branch. Paused channels, branch rollouts, update rollouts, and rollback directives are not supported for draft selection. These routes cannot reliably identify one current preview.

The example project is `mokosdavid/expo-drafts-lab`, with EAS project ID `e8ecb8b1-95ac-4f76-965a-df4b39ea3929`.

## Where publication runs

Each same-repository PR starts [`.github/workflows/drafts.yml`](../.github/workflows/drafts.yml). GitHub Actions checks out that PR's exact commit, installs the dependencies needed to read its app config, and uploads the source with EAS CLI 23.2.0 and `eas workflow:run`.

EAS executes [`example/.eas/workflows/publish-draft.yml`](../example/.eas/workflows/publish-draft.yml). Its prepackaged `update` job installs and compiles `expo-drafts`, checks the example app, bundles the JavaScript, and publishes the iOS update. The job uses the `preview` EAS environment and returns the complete `updates_json` output. See Expo's [update job documentation](https://docs.expo.dev/eas/workflows/pre-packaged-jobs/#update).

The GitHub dispatcher verifies the EAS project, channel, source commit, and returned updates before saving a publication report. The Actions summary links to the EAS workflow run. The artifact retains its existing name, `draft-catalog-entry`, for tooling compatibility; it is a report, and the app does not fetch it. The workflow does not write to the `drafts-catalog` branch.

EAS CLI uploads the local source archive when `--ref` is omitted, so this setup does not require an Expo GitHub app installation or project/repository link. The archive contains the PR checkout's Git metadata. The trusted control checkout and generated output files are sibling directories outside that repository and are excluded from the archive. Native EAS GitHub triggers are not also enabled. See [EAS workflow execution](https://docs.expo.dev/eas/cli/#eas-workflowrun-file).

Publications run concurrently across channels. EAS uses a concurrency group derived from the channel with `cancel_in_progress: true`, so a new publication cancels an older EAS run for the same PR. GitHub also cancels its obsolete dispatcher, and an interrupted waiter requests cancellation of its verified EAS run. Transient observation failures retry the same run with bounded backoff. The waiter times out after 45 minutes.

## Enable the workflow

1. Add an Expo access token with permission to publish updates for the project as the repository secret `EXPO_TOKEN`. A dedicated robot with a publishing role limits access to the owning Expo account; a personal token has access to all accounts available to its owner. See Expo's [programmatic access guide](https://docs.expo.dev/accounts/programmatic-access/) and [GitHub Actions setup](https://docs.expo.dev/eas-update/github-actions/).
2. Keep `.github/workflows/drafts.yml` and `cli/` on the default branch. Include `example/.eas/workflows/publish-draft.yml` on each PR branch. The dispatcher uses the default branch's control scripts and needs only `contents: read`.
3. Open or push to a PR from a branch in this repository. You can also run **Publish PR draft** manually from the Actions page, supplying a channel and title.
4. Sign in to Expo in the preview app with an account that can access the project, then refresh the picker. Each reviewer uses their own Expo session; the CI token remains in GitHub Actions.

The EAS workflow publishes from `example/`. To use it in your app repository, adjust the checkout paths, dependency install steps, EAS workflow location, and the dispatcher's `DRAFT_PROJECT_ID`. The supplied workflow publishes iOS only. [Native build requests](native-builds.md) use the same project and the existing Expo secret.

The example's EAS Build pre-install hook runs `npm ci --prefix ..` to install and compile the parent package before building the app. `example/fingerprint.config.js` excludes only that exact bootstrap script from fingerprint metadata, since it reproduces the existing local installation. Native sources, dependencies, app configuration, other scripts, and changes to the bootstrap command remain part of the runtime fingerprint.

The workflow skips fork PRs because they cannot use the Expo secret. It does not use `pull_request_target`. Anyone who can push a same-repository branch can run app code with the publishing token, so grant that ability only to trusted contributors and coding agents.

## Publish from an agent or your terminal

For automatic PR publishing, push your branch and open a PR. To run the same EAS workflow manually, commit your changes and run this from the app directory:

```bash
mkdir -p ../work
draft_commit=$(git rev-parse HEAD)
eas workflow:run .eas/workflows/publish-draft.yml --non-interactive --wait --json \
  --input channel=draft-pr-42 --input "name=Improve checkout" \
  --input "git_commit=$draft_commit" --input github_run_id=manual \
  > ../work/eas-workflow-result.json
```

The source is uploaded to EAS and the update job runs there. Once EAS reports success, refresh the picker. No catalog export or Git push is needed for discovery.

## Native compatibility

Use `"runtimeVersion": { "policy": "fingerprint" }` for your app and build preview binaries with EAS Build. Fingerprinting derives the runtime from native inputs, so adding a native dependency changes the runtime and disables the draft in an older build. A manually assigned runtime only works when you update it whenever native code changes. Expo explains both approaches in its [runtime version guide](https://docs.expo.dev/eas-update/runtime-versions/).

iOS and Android fingerprints can differ. EAS may publish separate platform update groups for one publication. Selection checks the iOS update ID and its runtime; a group ID is not an update ID.

A Release or internal distribution build must contain `expo-drafts`, `expo-updates`, and the package's config plugin. Keep the native package installed when building; the picker itself does not require a JavaScript import. For testing on an iOS simulator, build with `ios.simulator: true` in the EAS preview profile. Metro is used during export and does not need to run while reviewers use the app.

## Optional legacy JSON tooling

The package retains its JSON export and Git catalog writer commands for existing consumers. They are separate from direct EAS discovery. Supplying a legacy `catalogUrl` opts into that integration; the example no longer supplies one.

For example, export saved `eas update:view GROUP_ID --json` output:

```bash
node cli/index.mjs catalog \
  --input work/eas-update.json --output work/catalog.json \
  --project-id e8ecb8b1-95ac-4f76-965a-df4b39ea3929 \
  --channel draft-pr-42 --name "Improve checkout"
```

The command also accepts a workflow's full `updates_json`, including separate iOS and Android groups. `--merge existing.json` merges a previous catalog; `--output -` writes JSON to stdout. Optional `--pr-number`, `--pr-url`, and `--build-url` flags add metadata.

An explicit `node cli/publish-catalog.mjs --input work/catalog.json` publishes through an authenticated Git checkout. It retains the newest publication per channel and retries conflicting normal pushes. The legacy native build writer remains available too; the supplied native workflow uses `--no-publish` and saves only its verification report. Existing hosted JSON will stop advancing when you migrate to these workflows, so update legacy clients before relying on new publications.

Run the CLI tests with `node --test tests/cli/*.test.mjs`. They cover EAS identity and routing validation, network retries, workflow cancellation, strict native artifact checks, report-only observation, and legacy concurrent writers. Validate EAS workflow changes against the [current EAS Workflows schema](https://api.expo.dev/v2/workflows/schema).
