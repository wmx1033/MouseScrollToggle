#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
mkdir -p "$root/build"
tmp=$(mktemp -d "$root/build/.test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -D TESTING -parse-as-library "$root/Sources/MouseScrollToggle.swift" "$root/Tests/event-tests.swift" -o "$tmp/event-tests"
"$tmp/event-tests"
