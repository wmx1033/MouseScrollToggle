#!/bin/zsh
# Verify both failure and interruption cleanup with an orphaned mock child.
set -euo pipefail
root=${0:A:h:h}
outer=$(mktemp -d)
trap 'rm -rf "$outer"' EXIT
export TEST_ROOT="$root" CLEANUP_OUTER="$outer"
cat > "$outer/harness" <<'HARNESS'
#!/bin/zsh
set -euo pipefail
umask 077
tmp="$CLEANUP_OUTER/case"
export HOME="$tmp/home"
mkdir -p "$HOME/.config/mousescrolltoggle" "$HOME/.local/bin"
source "$TEST_ROOT/Tests/test-support.sh"
source "$TEST_ROOT/Tests/mock-runtime.sh"
cp "$tmp/core" "$HOME/.local/bin/mousescrolltoggle"
"$tmp/ctl" bootstrap
cat "$HOME/mock-pid" > "$CLEANUP_OUTER/observed"
touch "$CLEANUP_OUTER/ready"
[[ $1 != fail ]] || exit 1
zmodload zsh/zselect
zselect -t 1000 || true
HARNESS
n=0
for mode in fail interrupt; do
 rm -f "$outer/ready" "$outer/observed"
 /bin/zsh "$outer/harness" "$mode" & child=$!
 for i in {1..80}; do [[ ! -f "$outer/ready" ]] || break; sleep 0.05; done
 [[ -f "$outer/ready" ]] || { kill -KILL "$child" 2>/dev/null || true; exit 1; }
 core=$(cat "$outer/observed")
 [[ $mode != interrupt ]] || kill -TERM "$child"
 for i in {1..80}; do kill -0 "$child" 2>/dev/null || break; sleep 0.05; done
 kill -KILL "$child" 2>/dev/null || true
 rc=0; wait "$child" || rc=$?
 if [[ $mode == fail ]]; then [[ $rc == 1 ]]; else [[ $rc == 143 ]]; fi
 (( ++n ))
 [[ ! -d "$outer/case" ]]; (( ++n ))
 for i in {1..20}; do kill -0 "$core" 2>/dev/null || break; sleep 0.05; done
 ! kill -0 "$core" 2>/dev/null; (( ++n ))
done
print "PASS: $n failure/interruption cleanup checks (mock process, no launchctl)"
