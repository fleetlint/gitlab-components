# fleetlint components

A GitLab CI/CD component for [fleetlint](https://fleetlint.org): it checks a project's setup against its fleetlint rules and, with `pr: true`, opens merge requests with the onboarding configuration or the mechanical fixes.

A component version installs the fleetlint release of the same number: `fleetlint@0.8.1` runs fleetlint v0.8.1 (merge requests for fixes need a release after 0.8.1). The inputs are described in the [CI/CD catalog](https://gitlab.com/explore/catalog/fleetlint/components).

## Components

### fleetlint

```yaml
include:
  - component: gitlab.com/fleetlint/components/fleetlint@0.8.1
    inputs:
      fail-on: warning
      pr: true
```

Installs the release with fleetlint's install script of that tag and requires the cosign signature of its checksums (`verify: checksum` checks the checksum only). Every run checks the project, reports every finding in the merge request's Code Quality widget, keeps `fleetlint.json` as an artifact and fails at `fail-on` (default `error`).

With `pr: true`, a pipeline of the default branch also opens or updates a merge request:

- A project without a `.fleetlint.yaml` gets the onboarding merge request (`fleetlint init --pr`: the configuration, with the report as its description). The run is not gated: the project has not adopted a configuration yet.
- A project with one gets the mechanical fixes of its default branch (`fleetlint fix --apply --pr`, committed on `fleetlint/fixes` and updated on every run), and the run is gated as usual.

Other branches and merge request pipelines only check. The checkout of the job is not changed, so a protected default branch is fine. A pipeline schedule (Build, Pipeline schedules) keeps the fixes merge request current between pushes.

The job token cannot push or open merge requests, so `pr: true` needs `FLEETLINT_TOKEN`: a project access token with the `api` and `write_repository` scopes and the Developer role, as a masked CI/CD variable. Commits are authored as `fleetlint <fleetlint@noreply.<host>>` unless the job sets `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL`.

## Self-managed GitLab

A component can only be included from the instance it is published on. On a self-managed instance, mirror this project into a group there and publish it as a catalog project, or include the template by URL, which works on every instance:

```yaml
include:
  - remote: https://raw.githubusercontent.com/fleetlint/gitlab-components/0.8.1/templates/fleetlint.yml
    inputs:
      fail-on: warning
```

## Contribute

The source is [github.com/fleetlint/gitlab-components](https://github.com/fleetlint/gitlab-components), mirrored to [gitlab.com/fleetlint/components](https://gitlab.com/fleetlint/components); a version tag pushed there runs the release job, which publishes it to the catalog. `test/run.sh` runs the job in its image the way a runner does, with a stub for the commands that need a forge (needs `yq` and docker, or `CONTAINER=podman`). A release bumps the `version` default to the new fleetlint release and tags the same number without the `v`.
