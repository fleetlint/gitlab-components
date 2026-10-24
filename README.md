# fleetlint components

A GitLab CI/CD component for [fleetlint](https://fleetlint.org): it checks a project's setup against its fleetlint rules and, with `pr: true`, opens merge requests with the onboarding configuration or the mechanical fixes.

The inputs are described in the [CI/CD catalog](https://gitlab.com/explore/catalog/fleetlint/components). Versions are below.

## Components

### fleetlint

```yaml
include:
  - component: gitlab.com/fleetlint/components/fleetlint@0.1.0
    inputs:
      fail-on: warning
      pr: true
```

Installs the fleetlint release of `version` with fleetlint's install script of that tag and requires the cosign signature of its checksums (`verify: checksum` checks the checksum only). Every run checks the project, reports every finding in the merge request's Code Quality widget, keeps `fleetlint.json` as an artifact and fails at `fail-on` (default `error`).

With `pr: true`, a pipeline of the default branch also opens or updates a merge request:

- A project without a `.fleetlint.yaml` gets the onboarding merge request (`fleetlint init --pr`: the configuration, with the report as its description). The run is not gated: the project has not adopted a configuration yet.
- A project with one gets the mechanical fixes of its default branch (`fleetlint fix --apply --pr`, committed on `fleetlint/fixes` and updated on every run), and the run is gated as usual.

Other branches and merge request pipelines only check. The checkout of the job is not changed, so a protected default branch is fine. A pipeline schedule (Build, Pipeline schedules) keeps the fixes merge request current between pushes.

The job token cannot push or open merge requests, so `pr: true` needs `FLEETLINT_TOKEN`: a project access token with the `api` and `write_repository` scopes and the Developer role, as a masked CI/CD variable. Commits are authored as `fleetlint <fleetlint@noreply.<host>>` unless the job sets `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL`.

## Self-managed GitLab

A component can only be included from the instance it is published on. On a self-managed instance, mirror this project into a group there and publish it as a catalog project, or include the template by URL, which works on every instance:

```yaml
include:
  - remote: https://raw.githubusercontent.com/fleetlint/gitlab-components/0.1.0/templates/fleetlint.yml
    inputs:
      fail-on: warning
```

## Versions

The component has its own versions (semantic versioning, [CHANGELOG.md](CHANGELOG.md)), independent of fleetlint's. Each pins a fleetlint release as the `version` default; Renovate bumps it, and a release of the component follows. Set `version` to run another fleetlint release.

| Component | Installs by default | Needs |
|---|---|---|
| 0.1.0 | fleetlint v0.9.0 | `pr`: fleetlint 0.9.0 or newer |

## Contribute

The source is [github.com/fleetlint/gitlab-components](https://github.com/fleetlint/gitlab-components), mirrored to [gitlab.com/fleetlint/components](https://gitlab.com/fleetlint/components); a version tag pushed there runs the release job, which publishes it to the catalog. `test/run.sh` runs the job in its image the way a runner does, with a stub for the commands that need a forge (needs `yq` and docker, or `CONTAINER=podman`). A release dates the `[Unreleased]` section of CHANGELOG.md and tags its number without a `v`; the release job takes that section as the notes.
