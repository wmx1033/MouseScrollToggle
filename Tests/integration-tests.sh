#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
tmp=$(mktemp -d)
trap 'if [[ -f "$HOME/mock-pid" ]]; then kill $(cat "$HOME/mock-pid") 2>/dev/null || true; fi; rm -rf "$tmp"' EXIT
export HOME="$tmp/home space & xml"
mkdir -p "$HOME" "$tmp/repo/Scripts" "$tmp/repo/Sources"
cp "$root"/Scripts/*.sh "$tmp/repo/Scripts/"
cp "$root/Sources/MouseScrollToggle.swift" "$tmp/repo/Sources/"
export MST_TEST_MODE=1 MST_TEST_CTL="$tmp/ctl" MST_TEST_BUILD="$tmp/build"
cat > "$tmp/core" <<'CORE'
#!/bin/zsh
[[ ${1:-} != --version ]] || { print test; exit; }
trap 'print -r -- "$$ READY $(cat "$HOME/.config/mousescrolltoggle/request")" > "$HOME/.config/mousescrolltoggle/response"' USR1
trap 'exit 0' TERM
print -rn -- $$ > "$HOME/.config/mousescrolltoggle/ready-pid"
while true; do sleep 0.05; done
CORE
cat > "$tmp/build" <<'BUILD'
#!/bin/zsh
[[ ! -e "$HOME/fail-build" ]] || exit 1
cp "${0:h}/core" "$1"
chmod +x "$1"
BUILD
cat > "$tmp/ctl" <<'CTL'
#!/bin/zsh
case $1 in
 print)
 [[ -e "$HOME/loaded" ]] || exit 1
 print "program = $HOME/.local/bin/mousescrolltoggle"
 print "pid = $(cat "$HOME/mock-pid")"
 ;;
 bootstrap)
 [[ ! -e "$HOME/fail-start" ]] || exit 1
 "$HOME/.local/bin/mousescrolltoggle" >/dev/null 2>&1 &
 print $! > "$HOME/mock-pid"
 touch "$HOME/loaded"
 sleep 0.1
 ;;
 bootout)
 kill $(cat "$HOME/mock-pid") 2>/dev/null || true
 rm -f "$HOME/loaded"
 ;;
esac
CTL
chmod +x "$tmp"/{core,build,ctl}
cd "$tmp/repo"
n=0
check() { "$@" || { print -u2 "FAIL: $*"; exit 1; }; (( ++n )); }
expect_fail() { if "$@"; then print -u2 "FAIL expected error: $*"; exit 1; fi; (( ++n )); }
check ./Scripts/install.sh
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
print '<!-- user -->' >> "$HOME/.config/mousescrolltoggle/agent.plist"
expect_fail ./Scripts/install.sh
sed -i '' '$d' "$HOME/.config/mousescrolltoggle/agent.plist"
touch "$HOME/.config/mousescrolltoggle/other"
check ./Scripts/uninstall.sh
check ./Scripts/uninstall.sh
check test -f "$HOME/.config/mousescrolltoggle/other"
check test ! -d "$HOME/Library/LaunchAgents"
print "PASS: $n isolated checks (mock launchctl and core; no system/hardware claim)"
