# Publishing PR drafts

Each pull request gets a channel such as `draft-pr-42`. The app shows the PR title and update message. A channel keeps its latest publication, so another push replaces that PR's entry. Older PR channels remain available until they fall outside the 100 most recently published channels or you remove them from the catalog.

The channel routes the app to an update. The catalog identifies the specific update currently advertised on that channel. Before downloading, the app compares the selected platform's runtime version with the native build's runtime. After fetching, it checks the manifest's update ID. If another agent has published in the meantime, the app requires a catalog refresh instead of silently running a different update.

The example project is `mokosdavid/expo-drafts-lab`, with EAS project ID `e8ecb8b1-95ac-4f76-965a-df4b39ea3929`.

## Where publication runs

Each same-repository PR starts [`.github/workflows/drafts.yml`](../.github/workflows/drafts.yml). GitHub Actions checks out that PR's exact commit, installs the dependencies needed to read its app config, and uploads the source with `eas workflow:run`.

EAS executes [`example/.eas/workflows/publish-draft.yml`](../example/.eas/workflows/publish-draft.yml). Its prepackaged `update` job installs and compiles `expo-drafts`, checks the example app, bundles the JavaScript, and publishes the iOS update. The job uses the `preview` EAS environment and returns the complete `updates_json` output. See Expo's [update job documentation](https://docs.expo.dev/eas/workflows/pre-packaged-jobs/#update).

The GitHub dispatcher waits for that EAS run. It verifies the EAS project, channel, source commit, and each returned update's commit hash before generating catalog input. The Actions summary links to the EAS workflow run. A separate GitHub job runs the trusted catalog writer from the default branch and pushes the catalog using GitHub's automatic `GITHUB_TOKEN`.

The EAS CLI uploads the source archive when `--ref` is omitted, so this setup does not require an Expo GitHub app installation or project/repository link. The archive contains the PR checkout's Git metadata. The trusted control checkout and generated output files are sibling directories outside that repository and are excluded from the archive. Native EAS GitHub triggers are not also enabled, which prevents duplicate publications. See [EAS workflow execution](https://docs.expo.dev/eas/cli/#eas-workflowrun-file).

## Enable the workflow

1. Add an Expo access token with permission to publish updates for the project as the repository secret `EXPO_TOKEN`. A dedicated robot with a publishing role limits access to the owning Expo account; a personal token has access to all accounts available to its owner. See Expo's [programmatic access guide](https://docs.expo.dev/accounts/programmatic-access/) for token types and [GitHub Actions setup](https://docs.expo.dev/eas-update/github-actions/) for storing the secret.
2. Allow GitHub Actions to write repository contents. The catalog job requests `contents: write`; the dispatcher only requests read access. No GitHub write token needs to be stored in EAS.
3. Optionally set repository variable `DRAFT_BUILD_URL` to the EAS builds page or a specific installable build. The app can open this link when the selected draft needs a new native build.
4. Keep `.github/workflows/drafts.yml` and `cli/` on the default branch. Include `example/.eas/workflows/publish-draft.yml` on each PR branch. The dispatcher and catalog job use the default branch's control scripts.
5. Open or push to a PR from a branch in this repository. You can also run **Publish PR draft** manually from the Actions page, supplying a channel and title.

The EAS workflow publishes from `example/`. To use it in your app repository, adjust the checkout paths, dependency install steps, EAS workflow location, and the dispatcher's `DRAFT_PROJECT_ID`. The supplied workflow publishes iOS only.

The example's EAS Build pre-install hook runs `npm ci --prefix ..` to install and compile the parent package before building the app. `example/fingerprint.config.js` excludes only that exact bootstrap script from fingerprint metadata, since it reproduces the existing local installation. Native sources, dependencies, app configuration, other scripts, and changes to the bootstrap command remain part of the runtime fingerprint. This keeps existing previews compatible without weakening native-change detection.

The workflow skips fork PRs because they cannot use the Expo secret. It does not use `pull_request_target`. Anyone who can push a same-repository branch can run app code with the publishing token, so grant that ability only to trusted contributors and coding agents.

## Catalog hosting

The catalog job merges the new entry into `catalog.json` on the `drafts-catalog` branch. With a public repository, the app fetches it from:

```text
https://api.github.com/repos/davidmokos/expo-drafts/contents/catalog.json?ref=drafts-catalog
```

Only selected metadata is published. The catalog contains no Expo or GitHub access token, manifest permalink, or EAS account session. GitHub uses `EXPO_TOKEN` to dispatch and observe the run; EAS manages authentication for its update job. Workflow inputs contain only the channel, title, commit hash, and GitHub run ID. Titles, update messages, PR URLs, commit hashes, and runtime versions in this public catalog are visible to anyone who can access the URL. For a private app, host the same JSON behind your own authenticated endpoint and use your app's access control.

The sample uses GitHub's Contents API with the raw JSON media type and fresh request keys because the raw-file CDN can retain an older branch head. Anonymous API requests are limited per IP; host the same JSON on your own HTTPS endpoint for larger teams. Use the app's refresh control after publishing. An outdated catalog cannot bypass the runtime or fetched-ID checks.

PR publications run concurrently across channels. The EAS workflow uses a concurrency group derived from the channel and `cancel_in_progress: true`, so a new publication cancels an older EAS run for the same PR. GitHub also cancels its obsolete dispatcher, and an interrupted waiter requests cancellation of its verified EAS run. Transient observation failures retry the same run with bounded backoff; they do not cancel a healthy publication. The waiter times out after 45 minutes.

Each catalog writer reads the current branch, merges by channel and EAS publication time, then makes a normal Git push. If another writer wins the race, the losing writer fetches and merges again. It never force-pushes, and a late catalog job for an older publication cannot replace a newer publication. A single shared GitHub concurrency group is intentionally avoided because GitHub's default concurrency behavior can [replace pending jobs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#concurrency).

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

The source is uploaded to EAS and the update job runs there. From the package root, extract the job's update output and convert it to a catalog entry:

```bash
node - <<'NODE'
const fs = require('node:fs');
const run = JSON.parse(fs.readFileSync('work/eas-workflow-result.json', 'utf8'));
const job = run.jobs.find(job => job.key === 'publish_update');
if (run.status !== 'SUCCESS' || job?.status !== 'SUCCESS') {
  throw new Error('The EAS publication did not succeed.');
}
fs.writeFileSync('work/eas-update.json', job.outputs.updates_json);
NODE
```

```bash
node cli/index.mjs catalog \
  --input work/eas-update.json \
  --output work/catalog.json \
  --project-id e8ecb8b1-95ac-4f76-965a-df4b39ea3929 \
  --channel draft-pr-42 \
  --name "Improve checkout" \
  --pr-number 42 \
  --pr-url https://github.com/davidmokos/expo-drafts/pull/42 \
  --build-url https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds
```

`--merge existing.json` merges an existing catalog, and `--output -` writes JSON to stdout. The command accepts JSON from `eas update:view GROUP_ID --json` too. For a publication containing separate iOS and Android groups, use the full workflow `updates_json` output so both platforms appear in the draft.

To merge and publish through an authenticated Git checkout:

```bash
node cli/publish-catalog.mjs --input work/catalog.json
```

This creates or updates `origin/drafts-catalog` without changing your checked-out branch or files. It retains the newest publication per channel. Updating a title or build URL for the same publication replaces that entry's metadata.

## Native compatibility

Use `"runtimeVersion": { "policy": "fingerprint" }` for your app and build preview binaries with EAS Build. Fingerprinting derives the runtime from native inputs, so adding a native dependency changes the runtime and disables the draft in an older build. A manually assigned runtime only works when you update it whenever native code changes. Expo explains both approaches in its [runtime version guide](https://docs.expo.dev/eas-update/runtime-versions/).

iOS and Android fingerprints can differ. EAS may publish separate update groups for one `eas update` command. The catalog stores `groupId` and `runtimeVersion` on each platform update and keeps the entire publication in one channel entry. The draft-level `id` is a representative group ID, chosen deterministically from the publication. It is not used to fetch an update.

A release or internal distribution build must contain `expo-drafts`, `expo-updates`, and the package's config plugin. Keep the native package installed when building; the picker itself does not require a JavaScript import. For testing on an iOS simulator, build with `ios.simulator: true` in the EAS preview build profile. Metro is only used to export the bundle during publishing, and does not need to be running while reviewers use the app.

## Catalog schema

```json
{
  "schemaVersion": 1,
  "projectId": "e8ecb8b1-95ac-4f76-965a-df4b39ea3929",
  "generatedAt": "2026-09-08T12:01:00.000Z",
  "drafts": [
    {
      "id": "c1a66a49-a495-4243-b7e6-5f43e0e20101",
      "name": "Improve checkout",
      "channel": "draft-pr-42",
      "branch": "draft-pr-42",
      "message": "Adds checkout totals",
      "createdAt": "2026-09-08T12:00:00.000Z",
      "gitCommitHash": "726602fdadbf4d48045d606395fdd92dedce2d27",
      "pullRequest": {
        "number": 42,
        "url": "https://github.com/davidmokos/expo-drafts/pull/42"
      },
      "buildUrl": "https://expo.dev/accounts/mokosdavid/projects/expo-drafts-lab/builds",
      "updates": [
        {
          "id": "92e20c9c-8c92-4b41-a2db-58ca3d570101",
          "groupId": "c1a66a49-a495-4243-b7e6-5f43e0e20101",
          "platform": "ios",
          "runtimeVersion": "7ccdc372637438885754e1b43a53c78609cad298"
        }
      ]
    }
  ]
}
```

`branch`, `message`, `gitCommitHash`, `pullRequest`, and `buildUrl` are optional. Each draft requires at least one platform update. The CLI rejects rollback directives, duplicate platforms, invalid identifiers, mixed-branch publications, and catalogs from another EAS project.

Run the CLI tests with `node --test tests/cli/*.test.mjs`. They cover concurrent catalog publishers using a local bare Git repository, EAS output identity checks, retrying transient observation failures, and canceling an interrupted or timed-out EAS run. Validate `example/.eas/workflows/publish-draft.yml` against the [current EAS Workflows schema](https://api.expo.dev/v2/workflows/schema) when changing its jobs or concurrency settings.
