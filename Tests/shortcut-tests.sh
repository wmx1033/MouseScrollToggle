#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
tmp=$(mktemp -d)
trap 'if [[ -f "$HOME/mock-pid" ]]; then kill $(cat "$HOME/mock-pid") 2>/dev/null || true; fi; rm -rf "$tmp"' EXIT
export HOME="$tmp/home space & <xml> ' quote" TMPDIR="$tmp/temp space & ' quote"
mkdir -p "$HOME" "$TMPDIR" "$tmp/repo/Shortcuts" "$tmp/repo/Sources"
cp -R "$root/Scripts" "$tmp/repo/Scripts"
cp "$root/VERSION" "$tmp/repo/VERSION"
cp "$root/Sources/MouseScrollToggle.swift" "$tmp/repo/Sources/"
export MST_TEST_MODE=1 MST_TEST_LABEL="local.mousescrolltoggle.payload.test.$$" MST_TEST_CTL="$tmp/ctl" MST_TEST_BUILD="$tmp/build"
source "$root/Tests/mock-runtime.sh"
n=0
check() { "$@" || { print -u2 "FAIL: $*"; exit 1; }; (( ++n )); }
reject() { if "$@"; then print -u2 "FAIL expected rejection: $*"; exit 1; fi; (( ++n )); }
generate() { "$tmp/repo/Scripts/generate-shortcut.sh" "$tmp/payload.sh"; }
click() { /bin/zsh "$tmp/payload.sh" > "$tmp/out" 2> "$tmp/err"; }
output() { check test "$(cat "$tmp/out")" = "鼠标滚轮反转：$1"; }
count_builds() { wc -l < "$HOME/build-calls" | tr -d ' '; }
check "$root/Scripts/generate-shortcut.sh" --check
generate
check zsh -n "$tmp/payload.sh"
cp "$tmp/payload.sh" "$tmp/first"
generate
check cmp -s "$tmp/payload.sh" "$tmp/first"
reject /usr/bin/grep -Eq '/Users/|curl |wget |git clone|brew ' "$tmp/payload.sh"
# Run without the source checkout, from an unrelated working directory.
mv "$tmp/repo" "$tmp/hidden-repo"
cd /
check click
output 已开启
check test "$(cat "$HOME/.config/mousescrolltoggle/source.sha256")" = "$(shasum -a 256 "$root/Sources/MouseScrollToggle.swift" | cut -d ' ' -f1)"
expected_bundle=$(root="$tmp/hidden-repo"; source "$tmp/hidden-repo/Scripts/manifest.sh"; bundle_hash)
check test "$(cat "$HOME/.config/mousescrolltoggle/bundle.sha256")" = "$expected_bundle"
check test "$(count_builds)" = 1
check test "$(grep -c '^bootstrap$' "$HOME/ctl-calls")" = 1
mv "$tmp/hidden-repo" "$tmp/repo"
identity=$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")
check click; output 已关闭
check click; output 已开启
check test "$(count_builds)" = 1
check test "$identity" = "$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")"
# Version-only update, originally running: update must finish OFF, with no compile.
print 0.3.1 > "$tmp/repo/VERSION"
generate
check click; output 已关闭
check test "$(cat "$HOME/.config/mousescrolltoggle/version")" = 0.3.1
check test "$(count_builds)" = 1
check test "$identity" = "$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")"
# Script-only update applies the new behavior without touching the binary.
print "print -u2 'script-marker'" >> "$tmp/repo/Scripts/click.sh"
generate
check click; output 已开启
check grep -q script-marker "$tmp/err"
check test "$(count_builds)" = 1
# Core change compiles once. Updating an ON click finishes OFF.
bootstrap_before=$(grep -c '^bootstrap$' "$HOME/ctl-calls")
print '// source update' >> "$tmp/repo/Sources/MouseScrollToggle.swift"
generate
check click; output 已关闭
check test "$(count_builds)" = 2
check test "$(grep -c '^bootstrap$' "$HOME/ctl-calls")" = "$bootstrap_before"
# New source compile failure must not continue to toggle.
print '// failing update' >> "$tmp/repo/Sources/MouseScrollToggle.swift"
generate
touch "$HOME/fail-build"
reject click
check test ! -s "$tmp/out"
check test ! -e "$HOME/loaded"
rm "$HOME/fail-build"
# Core not ready / permission-like failure never reports ON.
touch "$HOME/not-ready"
reject click
check test ! -s "$tmp/out"
rm "$HOME/not-ready"
check click; output 已开启
# Failed restart and failed old-service recovery retain independent recovery material.
snapshot_bundle=$(cat "$HOME/.config/mousescrolltoggle/bundle.sha256")
snapshot_source=$(cat "$HOME/.config/mousescrolltoggle/source.sha256")
print '// restart failure' >> "$tmp/repo/Sources/MouseScrollToggle.swift"
generate
touch "$HOME/fail-start" "$HOME/not-healthy"
reject click
check test ! -s "$tmp/out"
backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
check test $#backups = 1
backup=$backups[1]
check test -f "$backup/old-bundle.sha256"
reject click
check grep -q '未完成事务' "$tmp/err"
backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
check test $#backups = 1
# Extraction has been cleaned; recovery relies solely on retained material.
extractions=("$TMPDIR"/mousescrolltoggle.*(N/))
check test $#extractions = 0
rm "$HOME/fail-start" "$HOME/not-healthy"
check /bin/zsh "$backup/recover.sh"
check test ! -d "$backup"
check test "$(cat "$HOME/.config/mousescrolltoggle/bundle.sha256")" = "$snapshot_bundle"
check test "$(cat "$HOME/.config/mousescrolltoggle/source.sha256")" = "$snapshot_source"
check click; output 已关闭
# An older release cannot downgrade or toggle.
print 0.3.0 > "$tmp/repo/VERSION"
generate
reject click
check test ! -s "$tmp/out"
check grep -q '拒绝降级' "$tmp/err"
print 0.3.1 > "$tmp/repo/VERSION"
generate
# Four concurrent clicks serialize the entire transaction; OFF -> ON -> OFF -> ON -> OFF.
pids=()
for i in {1..4}; do /bin/zsh "$tmp/payload.sh" > "$tmp/concurrent-$i" 2> "$tmp/concurrent-err-$i" & pids+=($!); done
for pid in $pids; do check wait "$pid"; done
check test ! -e "$HOME/loaded"
check test "$(grep -l '已开启' "$tmp"/concurrent-<-> | wc -l | tr -d ' ')" = 2
check test "$(grep -l '已关闭' "$tmp"/concurrent-<-> | wc -l | tr -d ' ')" = 2
rm -f "$HOME/.config/mousescrolltoggle/ready-pid"
"$HOME/.local/bin/mousescrolltoggle" & direct=$!
for i in {1..20}; do [[ -f "$HOME/.config/mousescrolltoggle/ready-pid" ]] && break; sleep 0.05; done
reject click
check test ! -s "$tmp/out"
kill "$direct"; wait "$direct" 2>/dev/null || true
check test ! -d "$HOME/Library/LaunchAgents"
extractions=("$TMPDIR"/mousescrolltoggle.*(N/))
check test $#extractions = 0
print "PASS: $n Phase 3 checks (isolated mocks; no UI/iCloud/hardware claim)"
