#!/bin/bash

read_helper_result() {
  local result_dir="$1"
  local launch_code="$2"
  local helper_code
  cat "$result_dir/stdout"
  cat "$result_dir/stderr" >&2
  # A fast app can exit before open attaches. Prefer the app's completed status.
  if [ -f "$result_dir/exit-code" ]; then
    helper_code="$(cat "$result_dir/exit-code")"
    case "$helper_code" in
      0|2|3|4|5|6|7) return "$helper_code" ;;
      *) echo 'Invalid helper completion status; result is unknown.' >&2; return 7 ;;
    esac
  fi
  echo "No helper completion status (open exit $launch_code). Do not assume the gesture succeeded." >&2
  return 7
}

main() (
  set -euo pipefail
  if [ "$#" -eq 0 ]; then set -- --help; fi
  repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  bundle="${ICON_MOVER_APP:-$repo_root/dist/iPhone Icon Mover RC.app}"
  if [ ! -d "$bundle" ]; then
    echo 'App not found. Run ./build.sh, or set ICON_MOVER_APP to the authorized .app path.' >&2
    exit 4
  fi
  for arg in "$@"; do
    if [ "$arg" = '--status-file' ]; then
      echo '--status-file is reserved for the launcher.' >&2
      exit 2
    fi
  done
  run_dir="$(mktemp -d "${TMPDIR:-/tmp}/icon-mover.XXXXXX")"
  trap 'rm -rf -- "$run_dir"' EXIT
  touch "$run_dir/stdout" "$run_dir/stderr"
  if /usr/bin/open -n -W -a "$bundle" --stdout "$run_dir/stdout" --stderr "$run_dir/stderr" \
    --args --status-file "$run_dir/exit-code" "$@"; then
    launch_code=0
  else
    launch_code=$?
  fi
  read_helper_result "$run_dir" "$launch_code"
)

# Sourcing defines only functions, allowing no-input tests of result handling.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
