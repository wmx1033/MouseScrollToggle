#!/bin/zsh
set -euo pipefail
root=${0:A:h:h}
tmp=$(mktemp -d)
source "$root/Tests/test-support.sh"
export HOME="$tmp/home" MST_TEST_MODE=1 MST_TEST_LABEL="local.mousescrolltoggle.doctor.test.$$" MST_TEST_CTL="$tmp/ctl" MST_TEST_BUILD="$tmp/build"
mkdir -p "$HOME"
source "$root/Tests/mock-runtime.sh"
n=0
check() { "$@" || { print -u2 "FAIL $*"; exit 1; }; (( ++n )); }
diagnose() { "$root/Scripts/doctor.sh" > "$tmp/report"; }
check diagnose
check grep -q 'BINARY=ABSENT' "$tmp/report"
check grep -q 'PERMISSION=UNKNOWN' "$tmp/report"
check /bin/zsh "$root/Shortcuts/shortcut-payload.sh" --doctor
check test ! -d "$HOME/.config"
check "$root/Scripts/install.sh"
check diagnose
check grep -q 'SERVICE=NOT_LOADED' "$tmp/report"
cp "$HOME/.config/mousescrolltoggle/source.sha256" "$tmp/source-hash"
rm "$HOME/.config/mousescrolltoggle/source.sha256"
check diagnose
check grep -q 'INSTALLATION=INCOMPLETE' "$tmp/report"
mv "$tmp/source-hash" "$HOME/.config/mousescrolltoggle/source.sha256"
# Real core permission-free probing cannot request authorization; mock is unsupported.
check grep -q 'PERMISSION=UNKNOWN' "$tmp/report"
check "$root/Scripts/control.sh" start
check diagnose
check grep -q 'TAP=HEALTHY' "$tmp/report"
touch "$HOME/not-healthy"
check diagnose
check grep -q 'TAP=ERROR' "$tmp/report"
rm "$HOME/not-healthy"
kill -TERM $(cat "$HOME/mock-pid")
for i in {1..40}; do kill -0 $(cat "$HOME/mock-pid") 2>/dev/null || break; sleep 0.05; done
check diagnose
check grep -q 'PROCESS=NOT_RUNNING' "$tmp/report"
check "$root/Scripts/control.sh" stop
mkdir -p "$HOME/.config/mousescrolltoggle/.install.test"
print ROLLING_BACK > "$HOME/.config/mousescrolltoggle/.install.test/phase"
check diagnose
check grep -q 'TRANSACTIONS=1' "$tmp/report"
check grep -q 'recover.sh' "$tmp/report"
if grep -Fq "$HOME" "$tmp/report"; then exit 1; fi
(( ++n ))
# Missing compiler and a broken install still yield a complete report.
mkdir "$tmp/tools"
printf '#!/bin/zsh\nexit 72\n' > "$tmp/tools/xcrun"; chmod +x "$tmp/tools/xcrun"
PATH="$tmp/tools:$PATH" diagnose
check grep -q 'SWIFT=UNAVAILABLE' "$tmp/report"
rm "$HOME/.config/mousescrolltoggle/.install.test/phase"
rmdir "$HOME/.config/mousescrolltoggle/.install.test"
# Lock contention is a bounded busy error, not a deadlock.
zsh -c 'zmodload zsh/system; zsystem flock -f fd "$HOME/.config/mousescrolltoggle/control.lock"; print ready > "$HOME/locked"; zmodload zsh/zselect; zselect -t 1500 || true' & holder=$!
for i in {1..40}; do [[ ! -e "$HOME/locked" ]] || break; sleep 0.05; done
rc=0; "$root/Scripts/control.sh" status > "$tmp/busy" 2>&1 || rc=$?
check test $rc = 75
kill "$holder"; wait "$holder" 2>/dev/null || true
# No toolchain: installer must fail without creating a binary.
rm "$HOME/.local/bin/mousescrolltoggle"
unset MST_TEST_BUILD
rc=0; PATH="$tmp/tools:$PATH" "$root/Scripts/install.sh" > "$tmp/install-error" 2>&1 || rc=$?
check test $rc != 0
check grep -q 'Xcode Command Line Tools' "$tmp/install-error"
# A file where the bin directory belongs is a deterministic unwritable destination.
rm -rf "$HOME/.local/bin"; touch "$HOME/.local/bin"
rc=0; "$root/Scripts/install.sh" > "$tmp/install-error" 2>&1 || rc=$?
check test $rc = 78
check grep -q '安装目录或日志目录不可写' "$tmp/install-error"
rm "$HOME/.local/bin"; mkdir "$HOME/.local/bin"; chmod 500 "$HOME/.local/bin"
export MST_TEST_BUILD="$tmp/build"
rc=0; "$root/Scripts/install.sh" > "$tmp/readonly-error" 2>&1 || rc=$?
check test $rc != 0
check test ! -e "$HOME/.local/bin/mousescrolltoggle"
chmod 700 "$HOME/.local/bin"
backups=("$HOME/.config/mousescrolltoggle"/.install.*(N/))
check test $#backups = 0
mkdir -p "$tmp/symlink-home/.config" "$tmp/target"
chmod 755 "$tmp/target"
ln -s "$tmp/target" "$tmp/symlink-home/.config/mousescrolltoggle"
rc=0; HOME="$tmp/symlink-home" "$root/Scripts/control.sh" status > "$tmp/symlink-error" 2>&1 || rc=$?
check test $rc = 78
check test "$(stat -f %OLp "$tmp/target")" = 755
# A broken executable with hanging flags cannot hang doctor or create a service.
rm -f "$HOME/.local/bin/mousescrolltoggle"
printf '#!/bin/zsh\nzmodload zsh/zselect\nzselect -t 1000 || true\n' > "$HOME/.local/bin/mousescrolltoggle"
chmod 700 "$HOME/.local/bin/mousescrolltoggle"
check diagnose
check grep -q 'PROTOCOL=UNKNOWN' "$tmp/report"
check grep -q 'PERMISSION=UNKNOWN' "$tmp/report"
print "PASS: $n diagnostic/failure checks (isolated adapters)"
