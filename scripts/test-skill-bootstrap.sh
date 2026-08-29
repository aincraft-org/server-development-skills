#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMMON="$SCRIPT_DIR/skill-bootstrap-common.sh"
CATALOG="$REPO_ROOT/skill-bootstrap/SKILL.md"

if [ ! -f "$COMMON" ]; then
  printf '!! skill-bootstrap-test: helper missing: %s\n' "$COMMON" >&2
  exit 1
fi
# shellcheck source=/dev/null
. "$COMMON"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/skill-bootstrap-test.XXXXXX")"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT HUP INT TERM

valid="$tmpdir/valid.catalog"
awk '
  $0 == "<!-- skill-bootstrap-catalog:v1 -->" { inside = 1 }
  inside { print }
  inside && $0 == "<!-- /skill-bootstrap-catalog -->" { exit }
' "$CATALOG" > "$valid"

[ -s "$valid" ] || {
  printf '!! skill-bootstrap-test: valid catalog block was not copied\n' >&2
  exit 1
}

assert_catalog_failure() {
  fixture="$1"
  label="$2"
  diagnostics="$tmpdir/$label.stderr"
  set +e
  catalog_validate "$fixture" 2> "$diagnostics"
  status=$?
  set -e
  [ "$status" -ne 0 ] || {
    printf '!! skill-bootstrap-test: %s unexpectedly passed\n' "$label" >&2
    exit 1
  }
  [ -s "$diagnostics" ] || {
    printf '!! skill-bootstrap-test: %s emitted no diagnostics\n' "$label" >&2
    exit 1
  }
}

catalog_validate "$valid"

rows="$(catalog_rows "$valid" all)"
row_count="$(printf '%s\n' "$rows" | awk 'NF { count++ } END { print count + 0 }')"
[ "$row_count" -eq 30 ] || {
  printf '!! skill-bootstrap-test: expected 30 expanded rows, got %s\n' "$row_count" >&2
  exit 1
}

first_row="$(printf '%s\n' "$rows" | sed -n '1p')"
[ "$first_row" = $'skill\tpaper\tpi\tproject-setup\tlocal\tworking-tree\tproject-setup\tlocal-skill' ] || {
  printf '!! skill-bootstrap-test: unexpected first normalized row\n' >&2
  exit 1
}

[ "$(catalog_tool_ref "$valid" skills)" = "1.5.23" ] || {
  printf '!! skill-bootstrap-test: tool ref lookup failed\n' >&2
  exit 1
}
[ "$(catalog_source_url https://github.com/googleworkspace/cli a3768d0e skills/gws-sheets)" = "https://github.com/googleworkspace/cli/tree/a3768d0e/skills/gws-sheets" ] || {
  printf '!! skill-bootstrap-test: source URL construction failed\n' >&2
  exit 1
}
command_output="$(print_command "npx" "--skill" "name with space")"
[ "$command_output" = "npx --skill name\\ with\\ space" ] || {
  printf '!! skill-bootstrap-test: shell-safe command printing failed\n' >&2
  exit 1
}


seven="$tmpdir/seven-fields.catalog"
awk '$0 ~ /^skill\tpaper\t/ && !changed { sub(/\t[^\t]*$/, ""); changed = 1 } { print }' "$valid" > "$seven"
assert_catalog_failure "$seven" seven-fields

duplicate="$tmpdir/duplicate-key.catalog"
awk '
  $0 == "<!-- /skill-bootstrap-catalog -->" { print first }
  $0 ~ /^skill\tpaper\t/ && first == "" { first = $0 }
  { print }
' "$valid" > "$duplicate"
assert_catalog_failure "$duplicate" duplicate-key

unknown_profile="$tmpdir/unknown-profile.catalog"
awk '$0 ~ /^skill\tpaper\t/ && !changed { sub(/^skill\tpaper\t/, "skill\tunknown\t"); changed = 1 } { print }' "$valid" > "$unknown_profile"
assert_catalog_failure "$unknown_profile" unknown-profile

unknown_mode="$tmpdir/unknown-mode.catalog"
awk '$0 ~ /\tlocal-skill$/ && !changed { sub(/\tlocal-skill$/, "\tunknown-mode"); changed = 1 } { print }' "$valid" > "$unknown_mode"
assert_catalog_failure "$unknown_mode" unknown-mode

printf 'skill-bootstrap parser tests: all checks passed\n'
