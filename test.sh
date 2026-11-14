#!/bin/bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p "$repo_root/.build/module-cache"
xcrun swiftc -swift-version 5 \
  -module-cache-path "$repo_root/.build/module-cache" \
  "$repo_root/Sources/Core.swift" "$repo_root/Sources/main.swift" \
  -o "$repo_root/.build/test-cli"
xcrun swiftc -swift-version 5 \
  -module-cache-path "$repo_root/.build/module-cache" \
  "$repo_root/Sources/Core.swift" "$repo_root/Tests/main.swift" \
  -o "$repo_root/.build/core-tests"
"$repo_root/.build/core-tests" "$repo_root/.build/test-cli"
/bin/bash "$repo_root/Tests/launcher.sh"
