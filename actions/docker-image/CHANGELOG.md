# Changelog

## 1.0.0 (2026-09-26)


### ⚠ BREAKING CHANGES

* **docker-image:** docker-release.yml's workflow_call no longer accepts `image`, `dockerfile`, `context`, `platforms`, or `build-args` inputs, and no longer builds/pushes/signs anything itself. Every caller must add a job that runs `jabrown93/ci/actions/docker-image` (gated on `needs.release.outputs.published`, granting contents:read/packages:write/id-token:write) to its own workflow file. See the README's `docker-release.yml` and `docker-image` sections for the full caller-side job.

### Features

* **docker-image:** move image build/push/sign into a composite action for correct cosign identity ([#118](https://github.com/jabrown93/ci/issues/118)) ([e3d08f2](https://github.com/jabrown93/ci/commit/e3d08f29f0363729d9458a26cb746cf34d35d2fd))
