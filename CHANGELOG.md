# Changelog

All notable changes to the component are documented here.
Format: Keep a Changelog. Versioning: Semantic Versioning, independent of fleetlint's.

## [Unreleased]

## [0.1.1] - 2026-10-30

### Changed

- Installs fleetlint v0.10.0 by default, whose `init` writes the detected stacks and published artifacts into `.fleetlint.yaml`, so the onboarding merge request shows what is checked.

## [0.1.0] - 2026-10-24

The first release. It installs fleetlint v0.9.0 by default.

### Added

- The component `fleetlint`: checks the project with every finding in the Code Quality widget, keeps `fleetlint.json`, and fails at `fail-on`.
- `pr: true`: a pipeline of the default branch opens the onboarding merge request, or the fixes merge request, with `FLEETLINT_TOKEN` (needs fleetlint 0.9.0 or newer).
- The release is installed with its checksum and cosign signature verified (`verify`), in an Alpine image of choice (`image`).
