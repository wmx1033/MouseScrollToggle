#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
[[ $(uname -s) == Darwin ]] || { print -u2 '构建失败：仅支持 macOS'; exit 1; }
xcrun --find swiftc >/dev/null || { print -u2 '构建失败：请安装 Xcode Command Line Tools'; exit 1; }
mkdir -p "$root/build"
tmp=$(mktemp -d "$root/build/.compile.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
xcrun swiftc -parse-as-library -O "$root/Sources/MouseScrollToggle.swift" -o "$tmp/mousescrolltoggle"
mv "$tmp/mousescrolltoggle" "$root/build/mousescrolltoggle"
print "构建成功：$root/build/mousescrolltoggle"
