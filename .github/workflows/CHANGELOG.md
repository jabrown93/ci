# Changelog

## [2.1.2](https://github.com/jabrown93/ci/compare/workflows-v2.1.1...workflows-v2.1.2) (2026-09-05)


### Bug Fixes

* **deps:** update docker/setup-qemu-action action to v4.3.0 ([#100](https://github.com/jabrown93/ci/issues/100)) ([6046fa9](https://github.com/jabrown93/ci/commit/6046fa9496f442a83c6e3d7d7409ff23db6ec530))

## [2.1.1](https://github.com/jabrown93/ci/compare/workflows-v2.1.0...workflows-v2.1.1) (2026-09-02)


### Bug Fixes

* **deps:** update anchore/sbom-action action to v0.24.2 ([#94](https://github.com/jabrown93/ci/issues/94)) ([9971027](https://github.com/jabrown93/ci/commit/9971027552b5814cdd683daaed925817572a3a70))

## [2.1.0](https://github.com/jabrown93/ci/compare/workflows-v2.0.0...workflows-v2.1.0) (2026-08-29)


### Features

* add a sbom-release reusable workflow for npm packages ([#83](https://github.com/jabrown93/ci/issues/83)) ([53321ff](https://github.com/jabrown93/ci/commit/53321ffe51499e2f54b58880adc3bb7d6911e8ac))
* attach a CycloneDX SBOM alongside the SPDX one ([#84](https://github.com/jabrown93/ci/issues/84)) ([e4b334a](https://github.com/jabrown93/ci/commit/e4b334a6518011b5c0c433bd9a5437c9a7a06990))

## [2.0.0](https://github.com/jabrown93/ci/compare/workflows-v1.1.1...workflows-v2.0.0) (2026-08-29)


### ⚠ BREAKING CHANGES

* dt-sbom-upload.yml is gone. Consumers publish SBOMs as release assets and attestations instead.

### Features

* remove the dt-sbom-upload reusable workflow ([21461f3](https://github.com/jabrown93/ci/commit/21461f36cbc300a52cd5c4b895aad4bf91f4f5ae))

## [1.1.1](https://github.com/jabrown93/ci/compare/workflows-v1.1.0...workflows-v1.1.1) (2026-08-23)


### Bug Fixes

* **deps:** update docker/setup-buildx-action action to v4.3.0 ([#69](https://github.com/jabrown93/ci/issues/69)) ([e960c96](https://github.com/jabrown93/ci/commit/e960c960ec5c392deef7da486567cc631d8723d5))

## [1.1.0](https://github.com/jabrown93/ci/compare/workflows-v1.0.0...workflows-v1.1.0) (2026-08-19)


### Features

* **workflows:** stage the release-commit script in both release workflows ([#67](https://github.com/jabrown93/ci/issues/67)) ([34a5bd6](https://github.com/jabrown93/ci/commit/34a5bd65c7c5b8f5e85ef5e05a57af3a110c253a))


### Bug Fixes

* **deps:** update actions/checkout action to v7.0.1 ([#22](https://github.com/jabrown93/ci/issues/22)) ([6ba010c](https://github.com/jabrown93/ci/commit/6ba010c76af550c139cd19727376dabe24281a99))
* **deps:** update dependency sigstore/cosign to v3.1.2 ([#45](https://github.com/jabrown93/ci/issues/45)) ([13208c9](https://github.com/jabrown93/ci/commit/13208c92c82104b01273ea2581f9acfa494f0258))
* **deps:** update dependency sigstore/cosign to v3.1.3 ([#56](https://github.com/jabrown93/ci/issues/56)) ([b22ff14](https://github.com/jabrown93/ci/commit/b22ff14a97e299f10aec46fba2ef174316bce1c2))
* **deps:** update docker/login-action action to v4.5.1 ([#35](https://github.com/jabrown93/ci/issues/35)) ([31bfa9c](https://github.com/jabrown93/ci/commit/31bfa9c5206c736af32406f2f7951ac9e9a82278))
* **deps:** update docker/login-action action to v4.5.2 ([#38](https://github.com/jabrown93/ci/issues/38)) ([6fa001c](https://github.com/jabrown93/ci/commit/6fa001cfea909faa2df1ab27708b5d1b344908d9))
* **deps:** update docker/login-action action to v4.6.0 ([#39](https://github.com/jabrown93/ci/issues/39)) ([0605e1c](https://github.com/jabrown93/ci/commit/0605e1cc159fbe543f102b4868c2a079b619aa03))
