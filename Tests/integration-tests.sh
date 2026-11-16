#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
tmp=$(mktemp -d)
trap 'if [[ -f "$HOME/mock-pid" ]]; then kill $(cat "$HOME/mock-pid") 2>/dev/null || true; fi; rm -rf "$tmp"' EXIT
export HOME="$tmp/home space & xml"
mkdir -p "$HOME" "$tmp/repo/Scripts" "$tmp/repo/Sources"
cp "$root/VERSION" "$tmp/repo/VERSION"
cp "$root"/Scripts/*.sh "$tmp/repo/Scripts/"
cp "$root/Sources/MouseScrollToggle.swift" "$tmp/repo/Sources/"
export MST_TEST_LABEL="local.mousescrolltoggle.test.$$"
export MST_TEST_MODE=1 MST_TEST_CTL="$tmp/ctl" MST_TEST_BUILD="$tmp/build"
source "$root/Tests/mock-runtime.sh"
cd "$tmp/repo"
n=0
check() { "$@" || { print -u2 "FAIL: $*"; exit 1; }; (( ++n )); }
expect_fail() { if "$@"; then print -u2 "FAIL expected error: $*"; exit 1; fi; (( ++n )); }
check ./Scripts/install.sh
backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
check test $#backups = 0
before=$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")
check ./Scripts/install.sh
check test "$before" = "$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")"
MST_VERSION=next ./Scripts/install.sh
check test "$before" = "$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")"
check ./Scripts/control.sh status
check ./Scripts/control.sh toggle
check ./Scripts/control.sh start
check ./Scripts/control.sh status
check ./Scripts/control.sh stop
check ./Scripts/control.sh stop
print changed >> Sources/MouseScrollToggle.swift
touch "$HOME/fail-build"
expect_fail ./Scripts/install.sh
check test "$before" = "$(stat -f '%i:%m' "$HOME/.local/bin/mousescrolltoggle")"
rm "$HOME/fail-build"
check ./Scripts/control.sh start
oldhash=$(shasum "$HOME/.local/bin/mousescrolltoggle")
touch "$HOME/fail-start"
expect_fail ./Scripts/install.sh
check test "$oldhash" = "$(shasum "$HOME/.local/bin/mousescrolltoggle")"
rm "$HOME/fail-start"
backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
check /bin/zsh "$backups[-1]/recover.sh"
check test ! -d "$backups[-1]"
check ./Scripts/control.sh start
# Stale reply and live process without a health responder must fail.
kill -STOP $(cat "$HOME/mock-pid")
expect_fail ./Scripts/control.sh status
kill -CONT $(cat "$HOME/mock-pid")
check ./Scripts/control.sh stop
./Scripts/control.sh start & p1=$!
./Scripts/control.sh start & p2=$!
wait $p1; wait $p2
(( ++n ))
# Exercise every retained-backup path and execute the generated recovery command.
check ./Scripts/control.sh stop
for fault in bootout-fail bootout-timeout restore-file old-service; do
  check ./Scripts/control.sh start
  print "// $fault" >> Sources/MouseScrollToggle.swift
  if [[ $fault == old-service ]]; then touch "$HOME/fail-start"
  else touch "$HOME/fail-update"; fi
  [[ $fault != bootout-fail && $fault != bootout-timeout ]] || touch "$HOME/$fault"
  if [[ $fault == restore-file ]]; then export MST_TEST_RESTORE_FAIL=version; fi
  expect_fail ./Scripts/install.sh > "$tmp/failure-output" 2>&1
  unset MST_TEST_RESTORE_FAIL
  backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
  backup=$backups[-1]
  check test -f "$backup/old-binary"
  for f in agent.plist version source.sha256 managed.sha256; do check test -f "$backup/old-$f"; done
  check /usr/bin/grep -q '恢复命令' "$tmp/failure-output"
  rm -f "$HOME"/{fail-start,fail-update,bootout-fail,bootout-timeout,rollback-active}
  check /bin/zsh "$backup/recover.sh"
  check test ! -d "$backup"
  check ./Scripts/control.sh stop
done
# A successful automatic rollback also cleans its snapshot.
check ./Scripts/control.sh start
print '// automatic rollback' >> Sources/MouseScrollToggle.swift
touch "$HOME/fail-once"
expect_fail ./Scripts/install.sh
backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
check test $#backups = 0
check ./Scripts/control.sh stop
# A non-launchd owner blocks lifecycle/destructive operations; stale PID is ignored.
: > "$HOME/.config/mousescrolltoggle/core.lock"
rm -f "$HOME/.config/mousescrolltoggle/ready-pid"
"$HOME/.local/bin/mousescrolltoggle" & holder=$!
while [[ ! -e "$HOME/.config/mousescrolltoggle/ready-pid" ]]; do sleep 0.05; done
print $$ > "$HOME/.config/mousescrolltoggle/ready-pid"
for command in './Scripts/control.sh status' './Scripts/control.sh stop' './Scripts/uninstall.sh' './Scripts/install.sh'; do
  expect_fail zsh -c "$command"
done
check test -x "$HOME/.local/bin/mousescrolltoggle"
# Real Swift binary must reject the occupied kernel lock before permission checks.
check "$root/Scripts/build.sh"
rc=0
env HOME="$HOME" "$root/build/mousescrolltoggle" || rc=$?
check test $rc = 5
kill $holder; wait $holder 2>/dev/null || true
check ./Scripts/control.sh status
check ./Scripts/control.sh stop
check test -n "$(kill -0 $$ 2>/dev/null && print alive)"
check ./Scripts/control.sh start
print '<!-- user -->' >> "$HOME/.config/mousescrolltoggle/agent.plist"
expect_fail ./Scripts/install.sh
sed -i '' '$d' "$HOME/.config/mousescrolltoggle/agent.plist"
touch "$HOME/.config/mousescrolltoggle/other"
check ./Scripts/uninstall.sh
check ./Scripts/uninstall.sh
check test -f "$HOME/.config/mousescrolltoggle/other"
check test ! -d "$HOME/Library/LaunchAgents"
print "PASS: $n isolated checks (mock launchctl and core; no system/hardware claim)"
