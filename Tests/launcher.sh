#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "$0")/.." && pwd)"
source "$repo_root/run.sh"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/icon-mover-test.XXXXXX")"
trap 'rm -rf -- "$fixture_dir"' EXIT
touch "$fixture_dir/stdout" "$fixture_dir/stderr"
expect_result() {
  local expected="$1"
  local actual=0
  read_helper_result "$fixture_dir" 0 > "$fixture_dir/out" 2> "$fixture_dir/err" || actual=$?
  if [ "$actual" -ne "$expected" ]; then
    echo "FAIL launcher result: expected $expected, got $actual" >&2
    exit 1
  fi
}
expect_result 7
echo 'PASS launcher missing completion is unknown, not success'
printf 'invalid\n' > "$fixture_dir/exit-code"
expect_result 7
echo 'PASS launcher rejects malformed completion'
printf '2\n' > "$fixture_dir/exit-code"
expect_result 2
echo 'PASS launcher propagates helper failure'
printf '0\n' > "$fixture_dir/exit-code"
printf 'planned output\n' > "$fixture_dir/stdout"
expect_result 0
[ "$(cat "$fixture_dir/out")" = 'planned output' ]
echo 'PASS launcher preserves stdout and successful completion'
actual=0
ICON_MOVER_APP="$fixture_dir/missing.app" main --help > /dev/null 2>&1 || actual=$?
[ "$actual" -eq 4 ]
echo 'PASS launcher diagnoses missing helper before open'
actual=0
ICON_MOVER_APP="$fixture_dir" main --status-file unexpected > /dev/null 2>&1 || actual=$?
[ "$actual" -eq 2 ]
echo 'PASS launcher rejects caller-supplied status file before open'
echo '6 launcher tests passed. LaunchServices was not invoked.'
