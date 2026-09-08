# Publishing PR drafts

Each pull request gets a channel such as `draft-pr-42`. The app shows the PR title and update message. A channel keeps its latest publication, so another push replaces that PR's entry. Older PR channels remain available until they fall outside the 100 most recently published channels or you remove them from the catalog.

The channel routes the app to an update. The catalog identifies the specific update currently advertised on that channel. Before downloading, the app compares the selected platform's runtime version with the native build's runtime. After fetching, it checks the manifest's update ID. If another agent has published in the meantime, the app requires a catalog refresh instead of silently running a different update.

The example project is `mokosdavid/expo-drafts-lab`, with EAS project ID `e8ecb8b1-95ac-4f76-965a-df4b39ea3929`.

## Enable the workflow

1. Add an Expo access token with permission to publish updates for the project as the repository secret `EXPO_TOKEN`. A dedicated robot with a publishing role limits access to the owning Expo account; a personal token has access to all accounts available to its owner. See Expo's [programmatic access guide](https://docs.expo.dev/accounts/programmatic-access/) for token types and [GitHub Actions setup](https://docs.expo.dev/eas-update/github-actions/) for storing the secret.
2. Allow GitHub Actions to write repository contents. The catalog job requests `contents: write`; the update job only requests read access.
3. Optionally set repository variable `DRAFT_BUILD_URL` to the EAS builds page or a specific installable build. The app can open this link when the selected draft needs a new native build.
4. Keep `.github/workflows/drafts.yml` and `cli/` on the default branch. The catalog job runs that trusted copy of the writer.
5. Open or push to a PR from a branch in this repository. You can also run **Publish PR draft** manually from the Actions page, supplying a channel and title.

The workflow publishes from `example/`. To use it in your app repository, adjust that working directory, dependency install steps, and the path used to read `extra.eas.projectId` from the app config.

The workflow skips fork PRs because they cannot use the Expo secret. It does not use `pull_request_target`. Anyone who can push a same-repository branch can run app code with the publishing token, so grant that ability only to trusted contributors and coding agents.

## Catalog hosting

The catalog job merges the new entry into `catalog.json` on the `drafts-catalog` branch. With a public repository, the app fetches it from:

```text
https://raw.githubusercontent.com/davidmokos/expo-drafts/drafts-catalog/catalog.json
```

Only selected metadata is published. The catalog contains no Expo or GitHub access token, manifest permalink, or EAS account session. The Expo token remains in GitHub Actions. Titles, update messages, PR URLs, commit hashes, and runtime versions in this public catalog are visible to anyone who can access the URL. For a private app, host the same JSON behind your own authenticated endpoint and use your app's access control.

GitHub's raw file CDN can briefly return the previous catalog. Use the app's refresh control after publishing. An outdated catalog cannot bypass the runtime or fetched-ID checks.

PR publish jobs run concurrently. Jobs for the same PR cancel obsolete runs. Each catalog writer reads the current branch, merges by channel and EAS publication time, then makes a normal Git push. If another writer wins the race, the losing writer fetches and merges again. It never force-pushes, and a late job for an older publication cannot replace a newer publication. A single shared GitHub concurrency group is intentionally avoided because GitHub's default concurrency behavior can [replace pending jobs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#concurrency).

## Publish from an agent or your terminal

Run EAS Update from the app directory with the same environment used by the preview build:

```bash
mkdir -p ../work
eas update --platform ios --channel draft-pr-42 --message "Adds checkout totals" \
  --environment preview --non-interactive --json > ../work/eas-update.json
```

Then convert its output from the package root:

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

`--merge existing.json` merges an existing catalog, and `--output -` writes JSON to stdout. The command accepts JSON from `eas update:view GROUP_ID --json` too. For a publication containing separate iOS and Android groups, use the full `eas update --json` response so both platforms appear in the draft.

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

Run the CLI tests with `node --test tests/cli/*.test.mjs`. They include concurrent publishers writing to a local bare Git repository.
