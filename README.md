# jabrown93/ci

Shared GitHub Actions CI library for all `jabrown93` repositories: reusable
workflows and composite actions, each versioned independently.

- **Reusable workflows** — in [`.github/workflows/`](.github/workflows),
  consumed via `uses:` at the **job** level.
- **Composite actions** — in [`actions/`](actions), consumed via `uses:` from a
  **step**.

> Org-wide *defaults* (issue/PR templates, `CODE_OF_CONDUCT`, `SECURITY`, the
> Renovate preset) live in [`jabrown93/.github`](https://github.com/jabrown93/.github),
> not here. This repo holds only the versioned CI library.

## Components and versioning

Each component has its **own** tag stream, cut automatically by
[`release.yml`](.github/workflows/release.yml) with
[release-please](https://github.com/googleapis/release-please) (manifest mode)
from the Conventional Commits merged to `main`:

| Component | Contents | Tag |
|---|---|---|
| `workflows` | all reusable workflows (they must share one flat `.github/workflows/` dir, so they share one stream) | `workflows-vX.Y.Z` |
| `generate-sbom` | the `generate-sbom` composite action | `generate-sbom-vX.Y.Z` |

Composite actions are versioned independently of each other and of the
workflows; the reusable workflows share the single `workflows` stream because
GitHub requires them all in `.github/workflows/` (no per-workflow subdirectory).

Consumers **pin by commit digest** with a `# <component>-vX.Y.Z` comment. The
tag is what makes that opaque digest readable and lets Renovate propose the
bump — the [shared preset](https://github.com/jabrown93/.github/blob/main/renovate-config.json)
carries a `customManager` that routes each ref to its component's tag stream.

```yaml
# reusable workflow (job level)
uses: jabrown93/ci/.github/workflows/<name>.yml@<sha> # workflows-v1.0.0

# composite action (step level)
uses: jabrown93/ci/actions/<name>@<sha> # <name>-v1.0.0
```

Trigger events (`push`, `pull_request`, `schedule`, branch filters) and
`concurrency` stay in the **caller** — a reusable workflow cannot declare them.

Each workflow/action file carries a header comment documenting its full inputs,
secrets, and operational constraints; the tables below are a summary.

---

## Reusable workflows

### `node-build.yml` — lint + format + build + test a Node.js project

Runs across a Node version matrix.

| input | default |
|---|---|
| `node-versions` | `'["20.x", "22.x", "24.x"]'` (JSON array) |
| `runs-on` | `ubuntu-latest` |

```yaml
name: Build and Lint
on: [push, pull_request]
jobs:
  build:
    uses: jabrown93/ci/.github/workflows/node-build.yml@<sha> # workflows-v1.0.0
```

### `codeql.yml` — CodeQL advanced analysis (single language)

Call once per language for multi-language repos.

| input | default |
|---|---|
| `language` | `javascript-typescript` |
| `build-mode` | `none` |
| `runs-on` | `ubuntu-latest` |

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

### `dt-sbom-upload.yml` — upload a CycloneDX SBOM to Dependency-Track

Runs on an in-cluster runner and POSTs an SBOM artifact to the homelab
Dependency-Track instance, exchanging the run's OIDC token for the DT key via
OpenBao. Generate the SBOM on a hosted runner with the `generate-sbom` action
first, then hand it over as an artifact.

| input | default |
|---|---|
| `runs-on` | *(required)* in-cluster runner label, e.g. `arc-oss-homebridge-onkyo` |
| `artifact-name` | `sbom` |
| `project-name` | `''` (defaults to `github.com/<owner>/<repo>`) |
| `project-version` | `''` (defaults to the caller's commit SHA) |
| `is-latest` | `'true'` |

> **Never** call this from a `pull_request` event — it would put fork-controlled
> code in reach of the in-cluster runner. The caller repo must be in the
> `dt-sbom-upload` role's allowlist and have an `arc-oss-<repo>` runner set.

### `stale.yml` — close stale issues and PRs

Every knob is overridable; the schedule trigger is defined by the caller.

| input | default |
|---|---|
| `days-before-stale` | `'30'` |
| `days-before-close` | `'7'` |
| `stale-issue-label` | `stale` |
| `stale-pr-label` | `no-pr-activity` |
| `exempt-issue-labels` / `exempt-pr-labels` | `work-in-progress,disable-stale-bot,needs-triage` |

(Plus the stale/close message inputs — see the workflow header.)

---

## Composite actions

### `generate-sbom` — CycloneDX SBOM for npm / maven / syft

Generates the SBOM and uploads it as an artifact. Used by **both** the
push-to-main `dt-sbom-upload.yml` caller and the advisory PR license check.

| input | default |
|---|---|
| `ecosystem` | *(required)* `npm`, `maven`, or `syft` (filesystem scan) |
| `sbom-path` | `sbom.cdx.json` |
| `artifact-name` | `sbom` |
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
they ship); bumps to this repo's own `release.yml` tooling stay `chore` and do
not release. See [`renovate.json`](renovate.json).
