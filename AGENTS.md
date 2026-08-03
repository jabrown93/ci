# AGENTS.md

## What this repo is

`jabrown93/ci` — shared GitHub Actions CI library for all `jabrown93` repos.
Pure YAML: reusable workflows and composite actions, each versioned and
released independently. No application code, no package.json, no build/lint/test
commands — nothing to compile or run locally. Validate changes by reading the
YAML and reasoning about GitHub Actions semantics.

## Layout and the two consumption patterns

- **Composite actions** — `actions/<name>/action.yaml`. Consumed via `uses:`
  at the **step** level. Preferred: they run in the caller's job, so the
  caller controls `runs-on`, matrix, and permissions. A composite action
  cannot declare `on:`, `runs-on`, a matrix, or job-level `permissions` —
  the caller's job always owns those.
- **Reusable workflows** — `.github/workflows/<name>.yml`, **bare** filename.
  Consumed via `uses:` at the **job** level. Reserved for what a composite
  action structurally cannot do: multi-job pipelines and workflow-level
  OIDC/permissions (`docker-release.yml`, `npm-release.yml`,
  `dt-sbom-upload.yml`).
- **Naming convention**: under `.github/workflows/`, a bare name is a shared
  reusable workflow for external use; a `_`-prefixed name (`_release.yml`) is
  this repo's own internal CI, not for consumers.
- Trigger events (`push`, `pull_request`, `schedule`), branch filters, and
  `concurrency` always stay in the caller — never add these to a reusable
  workflow or composite action here.

Every workflow/action file's header comment is the authoritative doc for its
inputs, secrets, and operational constraints — read it before changing
behavior. `README.md` mirrors those headers as a consumer-facing summary
table; update both when changing an interface.

## Versioning and releases (release-please, manifest mode)

Each component in `release-please-config.json` / `.release-please-manifest.json`
gets its own independent tag stream, cut by `_release.yml` via release-please
from Conventional Commits on `main` — nothing is hand-versioned:

| Component | Path | Tag |
|---|---|---|
| `workflows` | `.github/workflows/` (all reusable workflows share one stream — GitHub requires them flat in one dir) | `workflows-vX.Y.Z` |
| `generate-sbom` | `actions/generate-sbom/` | `generate-sbom-vX.Y.Z` |
| `codeql` | `actions/codeql/` | `codeql-vX.Y.Z` |
| `node-build` | `actions/node-build/` | `node-build-vX.Y.Z` |
| `go-build` | `actions/go-build/` | `go-build-vX.Y.Z` |
| `stale` | `actions/stale/` | `stale-vX.Y.Z` |
| `release-checkout` | `actions/release-checkout/` (internal, used only by the release workflows) | `release-checkout-vX.Y.Z` |
| `claude-review` | `actions/claude-review/` | `claude-review-vX.Y.Z` |

release-please attributes a commit to a component by the path of files it
touches. Consequences that matter when editing:

- A commit touching `.github/workflows/_release.yml` must use `ci:`/`chore:`
  — it lives under `.github/workflows/` but must never bump the `workflows`
  component, since no consumer calls it. `renovate.json` has a
  `packageRules` override enforcing this for Renovate-authored action bumps.
- Commit type drives the bump: `feat:` → minor, `fix:`/`perf:` → patch,
  `feat!:`/`BREAKING CHANGE:` footer → major, anything else → no release.
- Renovate bumps to third-party action SHAs **pinned inside** workflows/actions
  are labeled `fix` (they change what consumers execute) via the shared
  preset (`jabrown93/.github`), so they do release.

Consumers pin every `uses:` by commit digest with a trailing
`# <component>-vX.Y.Z` comment — the tag makes the opaque digest human-readable
and lets Renovate's `customManager` (in the shared preset) propose the bump.
Follow that same pin-by-sha-with-tag-comment convention for every third-party
action referenced inside this repo's own workflows/actions.

## Cross-referencing internal actions

A reusable workflow referencing `release-checkout` (or any composite action
in this repo) MUST use the full pinned ref
(`jabrown93/ci/actions/release-checkout@<sha>`), never a local `./actions/...`
path — a `./` ref inside a reusable workflow resolves against the **caller's**
checkout, not this repo, and silently fails to be found.

## Security-sensitive constraints (do not relax without explicit discussion)

- `generate-sbom` and `node-build` must always run on a **hosted** runner —
  `npm ci`/`npm install`/`mvn` execute untrusted dependency lifecycle
  scripts/plugins that must never touch an in-cluster runner.
- `go-build` must always run on a **hosted** runner too — Go resolves modules
  without running dependency code, but `go test` compiles and executes the
  checked-out repo, which is fork-controlled on a `pull_request`.
- `dt-sbom-upload.yml` runs on an **in-cluster** runner and must never be
  wired to a `pull_request` trigger — that would expose fork-controlled code
  to the cluster. It authenticates via OIDC → OpenBao exchange, and derives
  project identity from trusted GitHub context (`github.repository`/`github.sha`),
  never from values the SBOM-generating job produced.
- The release workflows authenticate as a GitHub App (via `release-checkout`),
  not the default `GITHUB_TOKEN`, so the release commit/tag/PR can clear the
  `main` branch ruleset (required signatures + required PR) through the app's
  bypass grant.
- `npm-release.yml`'s caller workflow must keep the exact filename registered
  for npm trusted publishing (typically `release.yaml`/`release.yml`) — OIDC
  trusted publishing matches on the caller repo + entry-point filename.

## Org-wide defaults live elsewhere

Issue/PR templates, `CODE_OF_CONDUCT`, `SECURITY.md`, and the shared Renovate
preset live in `jabrown93/.github`, not here. This repo holds only the
versioned CI library itself.
