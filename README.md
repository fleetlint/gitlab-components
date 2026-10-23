# fleetlint components

GitLab CI/CD components for [fleetlint](https://fleetlint.org): check a project's setup against its fleetlint rules, and open merge requests with the onboarding configuration or the mechanical fixes.

- [check](#check): the check, with findings in the merge request's Code Quality widget
- [pr](#pr): merge requests with fleetlint's changes, on scheduled and manually run pipelines

A component version installs the fleetlint release of the same number: `check@0.8.1` runs fleetlint v0.8.1 (`pr` needs a release after 0.8.1). The inputs are described in the [CI/CD catalog](https://gitlab.com/explore/catalog/fleetlint/components).

## Components

### check

```yaml
include:
  - component: gitlab.com/fleetlint/components/check@0.8.1
    inputs:
      fail-on: warning
```

Installs the release with fleetlint's install script of that tag, requires the cosign signature of its checksums (`verify: checksum` checks the checksum only), runs `fleetlint check`, reports every finding in the Code Quality widget and keeps `fleetlint.json` as an artifact. The job fails at `fail-on` (default `error`).

### pr

```yaml
include:
  - component: gitlab.com/fleetlint/components/pr@0.8.1
```

On pipelines run by a schedule or from the web UI, opens or updates a merge request: the onboarding configuration (`fleetlint init --pr`) when the project has no `.fleetlint.yaml`, else the mechanical fixes of the default branch (`fleetlint fix --apply --pr`, committed on `fleetlint/fixes` and updated on every run). The checkout of the job is not changed, so a protected default branch is fine.

The job token cannot push or open merge requests, so the job needs `FLEETLINT_TOKEN`: a project access token with the `api` and `write_repository` scopes and the Developer role, as a masked CI/CD variable. A schedule (Build, Pipeline schedules) runs it, for example weekly. Commits are authored as `fleetlint <fleetlint@noreply.<host>>` unless the job sets `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL`.

## Self-managed GitLab

A component can only be included from the instance it is published on. On a self-managed instance, mirror this project into a group there and publish it as a catalog project, or include a template by URL, which works on every instance:

```yaml
include:
  - remote: https://raw.githubusercontent.com/fleetlint/gitlab-components/0.8.1/templates/check.yml
    inputs:
      fail-on: warning
```

## Contribute

The source is [github.com/fleetlint/gitlab-components](https://github.com/fleetlint/gitlab-components), mirrored to [gitlab.com/fleetlint/components](https://gitlab.com/fleetlint/components); a version tag pushed there runs the release job, which publishes it to the catalog. `test/run.sh` runs the jobs in their image the way a runner does (needs `yq` and docker, or `CONTAINER=podman`). A release bumps the `version` default of every template to the new fleetlint release and tags the same number without the `v`.
