#!/bin/zsh
# Explicit mock adapters, used only with disposable HOME and service label.
cat > "$tmp/core" <<'CORE'
#!/bin/zsh
[[ ${1:-} != --version ]] || { print test; exit; }
[[ ${1:-} != --check-permission ]] || exit 64
[[ ! -e "$HOME/not-ready" ]] || exit 2
zmodload zsh/system
: >> "$HOME/.config/mousescrolltoggle/core.lock"
zsystem flock -t 0 -f corefd "$HOME/.config/mousescrolltoggle/core.lock" || exit 5
trap 'if [[ ! -e "$HOME/not-healthy" ]]; then print -r -- "$$ READY $(cat "$HOME/.config/mousescrolltoggle/request")" > "$HOME/.config/mousescrolltoggle/response"; fi' USR1
trap 'exit 0' TERM
print -rn -- $$ > "$HOME/.config/mousescrolltoggle/ready-pid"
for i in {1..3600}; do sleep 0.05; done
CORE
cat > "$tmp/build" <<'BUILD'
#!/bin/zsh
[[ ! -e "$HOME/fail-build" ]] || exit 1
print build >> "$HOME/build-calls"
cp "${0:h}/core" "$1"
chmod +x "$1"
BUILD
cat > "$tmp/ctl" <<'CTL'
#!/bin/zsh
print -r -- "$1" >> "$HOME/ctl-calls"
case $1 in
 kill) kill -USR1 $(cat "$HOME/mock-pid");;
 print)
 [[ -e "$HOME/loaded" ]] || exit 1
 print "program = $HOME/.local/bin/mousescrolltoggle"
 print "pid = $(cat "$HOME/mock-pid")"
 ;;
 bootstrap)
 if [[ -e "$HOME/fail-once" ]]; then rm "$HOME/fail-once"; exit 1; fi
 if [[ -e "$HOME/fail-update" ]]; then
   touch "$HOME/loaded" "$HOME/rollback-active"
   print 99999999 > "$HOME/mock-pid"
   return 1
 fi
 [[ ! -e "$HOME/fail-start" ]] || exit 1
 "$HOME/.local/bin/mousescrolltoggle" >/dev/null 2>&1 &
 print $! > "$HOME/mock-pid"
 ps -p $(cat "$HOME/mock-pid") -o lstart= > "$HOME/mock-identity"
 touch "$HOME/loaded"
 sleep 0.1
 ;;
 bootout)
 if [[ -e "$HOME/rollback-active" ]]; then
   [[ ! -e "$HOME/bootout-fail" ]] || exit 1
   [[ ! -e "$HOME/bootout-timeout" ]] || exit 0
 fi
 kill $(cat "$HOME/mock-pid") 2>/dev/null || true
 rm -f "$HOME/loaded"
 ;;
esac
CTL
chmod +x "$tmp"/{core,build,ctl}
