#!/usr/bin/env bash
# Runs the components' jobs in their image the way a GitLab runner would:
# inputs at their defaults, the job's variables exported, before_script and
# script in one shell. Needs yq and docker (CONTAINER=podman works too).
set -euo pipefail
cd "$(dirname "$0")/.."
container=${CONTAINER:-docker}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# render prints a template's jobs with the inputs given as name=value and
# the others at their defaults.
render() {
  local file=$1 spec body name value
  shift
  spec=$(awk '/^---$/ {exit} {print}' "$file")
  body=$(awk 'seen {print} /^---$/ {seen=1}' "$file")
  for name in $(yq '.spec.inputs | keys | .[]' <<<"$spec"); do
    value=$(yq ".spec.inputs.\"$name\".default" <<<"$spec")
    for given in "$@"; do
      [ "${given%%=*}" = "$name" ] && value=${given#*=}
    done
    body=${body//"\$[[ inputs.$name ]]"/$value}
  done
  if grep -q '\$\[\[' <<<"$body"; then
    echo "$1: inputs left unrendered" >&2
    return 1
  fi
  printf '%s\n' "$body"
}

# job runs a template's job in a copy of the project, which it keeps:
# job <template> <copy> <FLEETLINT_TOKEN> [input=value...]
job() {
  local dir="$work/$2"
  render "templates/$1.yml" "${@:4}" >"$work/$1.yml"
  yq '.[] | [(.variables | to_entries | .[] | "export " + .key + "=" + (.value | @sh))] + .before_script + .script | .[]' "$work/$1.yml" >"$work/$1.sh"
  cp -r . "$dir"
  "$container" run --rm -v "$dir:/builds/project:Z" -v "$work/$1.sh:/job.sh:ro,Z" -w /builds/project \
    -e CI_PROJECT_DIR=/builds/project -e CI_PROJECT_URL=https://gitlab.example/fleetlint/components \
    -e CI_SERVER_HOST=gitlab.example -e FLEETLINT_TOKEN="$3" \
    "$(yq '.[].image' "$work/$1.yml")" sh -e /job.sh
}

job check check "" fail-on=never
jq -e 'type == "array"' "$work/check/gl-code-quality-report.json" >/dev/null
jq -e '.summary' "$work/check/fleetlint.json" >/dev/null
echo "check: ran, wrote the Code Quality report"

if job check gate "" >"$work/gate.log" 2>&1 || ! grep -q "^FAIL " "$work/gate.log"; then
  echo "check: passed at fail-on error, though the project has error findings" >&2
  exit 1
fi
echo "check: fails at fail-on error"

if job pr pr "" >"$work/pr.log" 2>&1; then
  echo "pr: ran without FLEETLINT_TOKEN" >&2
  exit 1
fi
grep -q "needs FLEETLINT_TOKEN" "$work/pr.log"
echo "pr: refuses to run without FLEETLINT_TOKEN"
