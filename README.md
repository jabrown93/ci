# jabrown93/ci

Shared GitHub Actions CI library for all `jabrown93` repositories: reusable
workflows and composite actions, each versioned independently.

- **Composite actions** — in [`actions/`](actions), consumed via `uses:` from a
  **step**. Prefer these: they run on the caller's job, so the caller controls
  `runs-on`, matrix, and permissions.
- **Reusable workflows** — in [`.github/workflows/`](.github/workflows) with
  **bare** filenames, consumed via `uses:` at the **job** level. Reserved for
  the things that *cannot* be composite actions: multi-job pipelines and
  workflow-level OIDC/permissions (the release flows).

> **Naming tells you what a file is.** Under `.github/workflows/`, a **bare**
> name (`docker-release.yml`) is a shared reusable workflow; a name prefixed
> with **`_`** (`_release.yml`) is this repo's *own* CI and is not for external
> use. Composite actions all live under `actions/`, out of `.github/`.

> Org-wide *defaults* (issue/PR templates, `CODE_OF_CONDUCT`, `SECURITY`, the
> Renovate preset) live in [`jabrown93/.github`](https://github.com/jabrown93/.github),
> not here. This repo holds only the versioned CI library.

## Components and versioning

Each component has its **own** tag stream, cut automatically by
[`_release.yml`](.github/workflows/_release.yml) with
[release-please](https://github.com/googleapis/release-please) (manifest mode)
from the Conventional Commits merged to `main`:

| Component | Contents | Tag |
|---|---|---|
| `workflows` | the reusable workflows — `docker-release`, `npm-release` (they must share one flat `.github/workflows/` dir, so they share one stream) | `workflows-vX.Y.Z` |
| `generate-sbom` | the `generate-sbom` composite action | `generate-sbom-vX.Y.Z` |
| `codeql` | the `codeql` composite action | `codeql-vX.Y.Z` |
| `fossa` | the `fossa` composite action | `fossa-vX.Y.Z` |
| `node-build` | the `node-build` composite action | `node-build-vX.Y.Z` |
| `go-build` | the `go-build` composite action | `go-build-vX.Y.Z` |
| `stale` | the `stale` composite action | `stale-vX.Y.Z` |
| `release-checkout` | the `release-checkout` composite action (internal — used by the release workflows) | `release-checkout-vX.Y.Z` |
| `conventional-commits` | the `conventional-commits` composite action | `conventional-commits-vX.Y.Z` |
| `claude-review` | the `claude-review` composite action | `claude-review-vX.Y.Z` |

Composite actions are versioned independently of each other and of the
workflows; the reusable workflows share the single `workflows` stream because
GitHub requires them all in `.github/workflows/` (no per-workflow subdirectory).
`_release.yml` also lives there, but it is ci-internal — a change to it uses a
non-releasing commit type (`ci:`/`chore:`) so it never bumps `workflows`.

Consumers **pin by commit digest** with a `# <component>-vX.Y.Z` comment. The
tag is what makes that opaque digest readable and lets Renovate propose the
bump — the [shared preset](https://github.com/jabrown93/.github/blob/main/renovate-config.json)
carries a `customManager` that routes each ref to its component's tag stream.

```yaml
# composite action (step level)
uses: jabrown93/ci/actions/<name>@<sha> # <name>-v1.0.0

# reusable workflow (job level)
uses: jabrown93/ci/.github/workflows/<name>.yml@<sha> # workflows-v1.0.0
```

Trigger events (`push`, `pull_request`, `schedule`, branch filters) and
`concurrency` stay in the **caller** — a reusable workflow cannot declare them,
and a composite action cannot declare `on:`, `runs-on`, a matrix, or job-level
`permissions`; the caller's job owns all of those.

Each workflow/action file carries a header comment documenting its full inputs,
secrets, and operational constraints; the tables below are a summary.

---

## Composite actions

Consumed at the **step** level. The caller's job supplies `runs-on`, any matrix,
and — where the underlying tooling needs elevated scopes — `permissions`.

### `generate-sbom` — CycloneDX + SPDX SBOMs for npm / maven / syft

Generates **both** SBOM formats and uploads them as one artifact. CycloneDX
comes from the ecosystem-native generator (so it reports the resolved
dependency graph); SPDX comes from a single syft filesystem scan of the tree
those generators just installed.

| input | default |
|---|---|
| `ecosystem` | *(required)* `npm`, `maven`, or `syft` (filesystem scan) |
| `sbom-path` | `sbom.cdx.json` |
| `spdx-path` | `sbom.spdx.json` |
| `artifact-name` | `sbom` (holds both files) |
| `node-version` | `'24'` (ecosystem `npm`) |
| `cyclonedx-npm-version` | `4.2.1` (ecosystem `npm`) |
| `java-version` | `'25'` (ecosystem `maven`) |
| `java-distribution` | `corretto` (ecosystem `maven`) |

**Always run this on a hosted runner.** `npm ci` and `mvn` execute untrusted
dependency lifecycle scripts and build plugins that must never touch an
in-cluster runner. The action does **not** check out the repo; the caller does.

```yaml
      - uses: actions/checkout@<sha> # v7.0.0
      - uses: jabrown93/ci/actions/generate-sbom@<sha> # generate-sbom-v1.0.0
        with:
          ecosystem: maven
          sbom-path: target/sbom.cdx.json
```

### `fossa` — FOSSA licence and dependency scan

Wraps `fossas/fossa-action` so its pin is bumped once here instead of drifting
across consumers. Does **not** check out the repo; the caller does.

| input | default |
|---|---|
| `api-key` | *(required)* FOSSA API key |
| `run-tests` | `'false'` (set `'true'` to fail the job on a policy violation) |

> `FOSSA_API_KEY` is write-scoped, so never wire this to a `pull_request` event
> on a public repo.

```yaml
      - uses: actions/checkout@<sha> # v7.0.1
      - uses: jabrown93/ci/actions/fossa@<sha> # fossa-v1.0.0
        with:
          api-key: ${{ secrets.FOSSA_API_KEY }}
```

### `node-build` — lint + format + build + test a Node.js project

Checks out the repo, then lint + `prettier --check` + build + test for **one**
Node version. A composite action can't declare a matrix, so the **caller owns
the version matrix** and `runs-on`.

| input | default |
|---|---|
| `node-version` | `24.x` |

**Always run this on a hosted runner.** `npm install` executes untrusted
dependency lifecycle scripts that must never touch an in-cluster runner.

```yaml
name: Build and Lint
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        node-version: ['22.x', '24.x']
    steps:
      - uses: jabrown93/ci/actions/node-build@<sha> # node-build-v1.0.0
        with:
          node-version: ${{ matrix.node-version }}
```

### `go-build` — build + vet + test + gofmt-check a Go module

Checks out the repo, then `go build` + `go vet` + `go test` + a gofmt gate. The
toolchain version comes from the consumer's `go.mod`, so a repo never pins its
Go version in two places. Vendored modules work unmodified — the Go commands
pick `-mod=vendor` themselves and the gofmt gate skips `./vendor`.

| input | default |
|---|---|
| `go-version` | `''` (empty — read from `go-version-file`) |
| `go-version-file` | `go.mod` |
| `packages` | `./...` |

**Always run this on a hosted runner.** On a fork `pull_request` the
checked-out code is untrusted and `go test` executes it.

```yaml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: jabrown93/ci/actions/go-build@<sha> # go-build-v1.0.0
```

### `codeql` — CodeQL advanced analysis (single language)

Checks out the repo, then runs CodeQL init + analyze. Call once per language for
multi-language repos. The **caller's job must grant CodeQL's permissions**.

| input | default |
|---|---|
| `language` | `javascript-typescript` |
| `build-mode` | `none` |

```yaml
name: CodeQL
on: [push, pull_request]
jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      packages: read
      actions: read
      contents: read
    steps:
      - uses: jabrown93/ci/actions/codeql@<sha> # codeql-v1.0.0
        with:
          language: javascript-typescript
```

### `stale` — close stale issues and PRs

Wraps `actions/stale` with the shared defaults; every knob is overridable. The
**caller supplies the `schedule` trigger and the permissions**.

| input | default |
|---|---|
| `days-before-stale` | `'30'` |
| `days-before-close` | `'7'` |
| `stale-issue-label` | `stale` |
| `stale-pr-label` | `no-pr-activity` |
| `exempt-issue-labels` / `exempt-pr-labels` | `work-in-progress,disable-stale-bot,needs-triage` |

(Plus the stale/close message inputs — see the action header.)

```yaml
name: Stale
on:
  schedule:
    - cron: '0 0 * * *'
jobs:
  stale:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      pull-requests: write
      actions: write
    steps:
      - uses: jabrown93/ci/actions/stale@<sha> # stale-v1.0.0
```

### `release-checkout` — app-token + branch-tip checkout for a release job

**Internal.** Mints a GitHub App token and checks out the branch tip
(`fetch-depth: 0`, `ref: github.ref`) for a semantic-release job, exposing the
token as an output. Used by `docker-release.yml` and `npm-release.yml` to remove
their duplicated app-token + checkout preamble.

| input | default |
|---|---|
| `app-id` | *(required)* GitHub App client id |
| `app-private-key` | *(required)* GitHub App private key |
| `fetch-depth` | `'0'` |

output: `token` — the minted installation token, for the release step.

> A reusable workflow must reference this by its **full pinned ref**
> (`jabrown93/ci/actions/release-checkout@<sha>`), **not** `./actions/release-checkout`
> — a local `./` ref used from inside a reusable workflow resolves against the
> **caller's** checkout, not this repo.

### `conventional-commits` — enforce Conventional Commits on a PR's title and commits

Checks the PR title and every commit's subject line against
[Conventional Commits](https://www.conventionalcommits.org). The title check
wraps [`amannn/action-semantic-pull-request`](https://github.com/amannn/action-semantic-pull-request);
the commit check is a small `gh api`-backed script (no equivalent SHA-pinnable
action exists — the community-standard `wagoid/commitlint-github-action` is a
Docker container action pulling a floating Docker Hub tag, which this repo's
pin-by-commit-digest convention can't express). GitHub's default revert-PR
title/commit (`Revert "..."`) and merge commits are allowed through both
checks without a rewrite.

| input | default |
|---|---|
| `types` | `feat,fix,docs,style,refactor,perf,test,build,ci,chore,revert` |
| `check-title` | `'true'` |
| `check-commits` | `'true'` |

```yaml
name: Conventional commits
on:
  pull_request:
    types: [opened, reopened, edited, synchronize]
permissions:
  pull-requests: read
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: jabrown93/ci/actions/conventional-commits@<sha> # conventional-commits-v1.0.0
```

### `claude-review` — AI code review on a pull request

Wraps `anthropics/claude-code-action`, authenticated with a Claude Pro/Max
**subscription OAuth token** (via `claude setup-token`) instead of a
pay-as-you-go API key. Posts findings as inline PR review comments plus a
progress-tracking top-level comment. Model is hardcoded to `claude-sonnet-5`
with no `claude_args` passthrough — a deliberate token-cost guardrail, not a
per-caller knob. The **caller supplies the `pull_request` trigger**, the
`contents:read`/`pull-requests:write`/`id-token:write` permissions, the
`CLAUDE_CODE_OAUTH_TOKEN` secret, and any author filtering (e.g. skipping
Renovate PRs).

The [Claude GitHub App](https://github.com/apps/claude) must also be installed
on the consuming repo. This action does not pass `github_token`, so
`claude-code-action` uses its default path: exchanging the job's OIDC token
(hence `id-token: write`) for a Claude App installation token, which is also
what makes comments appear as the app rather than `github-actions[bot]`.
Without the app installed the run fails at that exchange, before any review is
posted.

| input | default |
|---|---|
| `claude-code-oauth-token` | *(required)* OAuth token from `claude setup-token` |
| `prompt` | built-in code quality/security/performance/testing/docs review focus |
| `track-progress` | `'true'` |

```yaml
name: Claude PR review
on:
  pull_request:
    types: [opened, ready_for_review, reopened]
jobs:
  review:
    if: github.actor != 'renovate-jaredbrown-io[bot]'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: jabrown93/ci/actions/claude-review@<sha> # claude-review-v1.0.0
        with:
          claude-code-oauth-token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

---

## Reusable workflows

Consumed at the **job** level (`jobs.<id>.uses:`). These stay reusable workflows
because they need what a composite action can't express: multiple dependent jobs
and workflow-level OIDC/permissions.

### `docker-release.yml` — semantic-release + build/push/sign a multi-arch image

Two jobs (`release` → `image`) so a build failure never strands a
tagged-but-imageless release. Authenticates as a GitHub App, then builds,
pushes, and keyless-signs a multi-arch image to GHCR.

| input | default |
|---|---|
| `image` | *(required)* e.g. `ghcr.io/jabrown93/crosswatch` |
| `dockerfile` | `./Dockerfile` |
| `context` | `.` |
| `platforms` | `linux/amd64,linux/arm64` |
| `build-args` | `""` (appended after the automatic `APP_VERSION=v<version>`) |
| `extra-plugins` | `""` (extra semantic-release plugins) |

| secret | |
|---|---|
| `APP_ID` | *(required)* GitHub App client id used to mint the release token |
| `APP_PRIVATE_KEY` | *(required)* GitHub App private key |

### `npm-release.yml` — semantic-release + npm publish with provenance (OIDC)

Authenticates as a GitHub App and publishes to npm via OIDC trusted publishing.

| input | default |
|---|---|
| `node-version` | `'24'` |

| secret | |
|---|---|
| `APP_ID` | *(required)* |
| `APP_PRIVATE_KEY` | *(required)* |

> npm trusted publishing matches on the **caller** workflow's repo and
> entry-point filename, so the caller workflow must stay named `release.yaml`/
> `release.yml` (whatever is registered on npmjs.org) and trigger on push to the
> release branches.

---

## Releasing

Releases are cut automatically. release-please opens a per-component release PR
as commits land on `main`; merging it tags `<component>-vMAJOR.MINOR.PATCH` and
publishes a GitHub Release. Nothing is versioned by hand.

| commit touching a component's files | effect |
|---|---|
| `feat: …` | minor |
| `fix: …` / `perf: …` | patch |
| `feat!: …` or `BREAKING CHANGE:` footer | major |
| anything else (`ci:`, `docs:`, `chore:`) | no release |

Renovate labels bumps to the third-party action SHAs pinned **inside** the
reusable workflows / actions as `fix` (they change what consumers execute, so
they ship); bumps to this repo's own `_release.yml` tooling stay `chore` and do
not release. See [`renovate.json`](renovate.json).
