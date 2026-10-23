#!/usr/bin/env bash
# Runs the component's job in its image the way a GitLab runner would:
# inputs rendered, the job's variables exported, before_script and script
# in one shell. A stub answers fleetlint's --pr commands, which need a forge.
# Needs yq and docker (CONTAINER=podman works too).
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
    echo "$file: inputs left unrendered" >&2
    return 1
  fi
  printf '%s\n' "$body"
}

# job runs the job in a fresh copy of the project, whose log it keeps:
# job <name> <branch> <FLEETLINT_TOKEN> [input=value...]
# A function prepare_<name>, if defined, edits the copy first.
job() {
  local dir="$work/$1"
  cp -r . "$dir"
  if declare -F "prepare_$1" >/dev/null; then "prepare_$1" "$dir"; fi
  render templates/fleetlint.yml "${@:4}" >"$work/$1.yml"
  yq '.[] | [(.variables | to_entries | .[] | "export " + .key + "=" + (.value | @sh))] + .before_script + .script | .[]' "$work/$1.yml" >"$work/$1.sh"
  "$container" run --rm -v "$dir:/builds/project:Z" -v "$work/$1.sh:/job.sh:ro,Z" -v "$PWD/test/stub:/stub:ro,Z" -w /builds/project \
    -e CI_PROJECT_DIR=/builds/project -e CI_PROJECT_URL=https://gitlab.example/fleetlint/components \
    -e CI_SERVER_HOST=gitlab.example -e CI_DEFAULT_BRANCH=main -e CI_COMMIT_BRANCH="$2" -e FLEETLINT_TOKEN="$3" \
    -e PATH=/stub:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$(yq '.[].image' "$work/$1.yml")" sh -e /job.sh >"$work/$1.log" 2>&1
}

# GitLab refuses a component whose spec description is longer than 256 characters.
len=$(awk '/^---$/ {exit} {print}' templates/fleetlint.yml | yq '.spec.description | length')
[ "$len" -le 256 ] || { echo "spec description: $len characters, GitLab allows 256" >&2; exit 1; }

fail() {
  echo "$1" >&2
  [ -f "$work/$2.log" ] && tail -5 "$work/$2.log" >&2
  exit 1
}

job check main "" fail-on=never || fail "check: failed" check
jq -e 'type == "array"' "$work/check/gl-code-quality-report.json" >/dev/null
jq -e '.summary' "$work/check/fleetlint.json" >/dev/null
echo "check: ran, wrote the Code Quality report"

if job gate main "" || ! grep -q "^FAIL " "$work/gate.log"; then
  fail "gate: passed at fail-on error, though the project has error findings" gate
fi
echo "gate: fails at fail-on error"

if job notoken main "" pr=true; then
  fail "pr: ran without FLEETLINT_TOKEN" notoken
fi
grep -q "needs FLEETLINT_TOKEN" "$work/notoken.log" || fail "pr: no message about FLEETLINT_TOKEN" notoken
echo "pr: refuses to run without FLEETLINT_TOKEN"

job branch feature "" pr=true fail-on=never || fail "branch: failed" branch
if grep -q "^stub:" "$work/branch.log"; then
  fail "pr: proposed changes from a branch other than the default" branch
fi
echo "pr: only checks off the default branch"

job fixes main token pr=true fail-on=never || fail "fixes: failed" fixes
grep -q "^stub: fleetlint -C . fix --apply --pr" "$work/fixes.log" || fail "pr: no fixes merge request for a configured project" fixes
echo "pr: proposes the fixes of a configured project"

prepare_onboarding() { rm "$1/.fleetlint.yaml"; }
job onboarding main token pr=true || fail "onboarding: gated or failed" onboarding
grep -q "^stub: fleetlint -C . init --pr" "$work/onboarding.log" || fail "pr: no onboarding merge request for a project without a configuration" onboarding
grep -q "not gated" "$work/onboarding.log" || fail "pr: the onboarding run was gated" onboarding
echo "pr: onboards a project without a configuration, without gating it"
