#!/bin/zsh
# Explicit opt-in: operates stable installed service, never installs or requests permission.
set -euo pipefail
root=${0:A:h:h}
[[ ${1:-} == --live ]] || { print -u2 '仅在授权后手动执行：system-tests.sh --live（临时启停本用户服务，结束保持停止）'; exit 64; }
svc="gui/$(id -u)/local.mousescrolltoggle"
if /bin/launchctl print "$svc" >/dev/null 2>&1; then print -u2 '拒绝：已有加载服务，请先安排停止，避免干扰现有使用'; exit 75; fi
direct=''
finish_direct() {
  [[ -n $direct ]] || return 0
  kill -INT "$direct" 2>/dev/null || true
  for i in {1..40}; do
    if ! kill -0 "$direct" 2>/dev/null; then wait "$direct"; direct=''; return 0; fi
    sleep 0.05
  done
  kill -KILL "$direct" 2>/dev/null || true
  wait "$direct" 2>/dev/null || true
  direct=''
  print -u2 '前台实例信号退出超时，已强制清理'
  return 1
}
trap 'finish_direct || true; "$root/Scripts/control.sh" stop >/dev/null 2>&1 || print -u2 "清理失败：请手动执行 Scripts/control.sh stop 并检查服务状态"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
pid_of() { /bin/launchctl print "$svc" | sed -n 's/^[[:space:]]*pid = \([0-9]*\)$/\1/p'; }
"$root/Scripts/control.sh" start
"$root/Scripts/doctor.sh"
first=$(pid_of)
"$root/Scripts/control.sh" start
[[ $first == $(pid_of) ]]; print 'PASS repeated start same PID'
rc=0; "$HOME/.local/bin/mousescrolltoggle" >/dev/null 2>&1 || rc=$?
[[ $rc == 5 ]]; print 'PASS second real core rejected exit=5'
for sig in SIGTERM SIGINT SIGKILL; do
 /bin/launchctl kill "$sig" "$svc"
 for i in {1..30}; do
   rc=0; "$root/Scripts/control.sh" status >/dev/null || rc=$?
   (( rc == 1 )) && break
   sleep 0.1
 done
 [[ $rc == 1 ]]; print "PASS $sig exit detected (service loaded, tap unhealthy)"
 "$root/Scripts/control.sh" start
done
"$root/Scripts/control.sh" stop
sleep 1
"$root/Scripts/control.sh" status
print 'PASS manual stop remains stopped after 1s'
# Log cap is tested by preloading only this project stderr log while stopped.
log="$HOME/Library/Logs/MouseScrollToggle/stderr.log"
dd if=/dev/zero bs=1024 count=257 >> "$log" 2>/dev/null
"$root/Scripts/control.sh" start
bytes=$(stat -f %z "$log")
(( bytes < 262144 )); print "PASS real stderr cap bytes=$bytes"
"$root/Scripts/control.sh" stop
# An unmanaged real core is never stopped by a guessed PID, nor removed/replaced.
"$HOME/.local/bin/mousescrolltoggle" >/dev/null 2>&1 & direct=$!
ready=0
for i in {1..40}; do
 if [[ $(cat "$HOME/.config/mousescrolltoggle/ready-pid" 2>/dev/null) == "$direct" ]]; then ready=1; break; fi
 sleep 0.05
done
(( ready == 1 ))
for operation in status stop; do
 rc=0; "$root/Scripts/control.sh" "$operation" >/dev/null 2>&1 || rc=$?
 [[ $rc == 1 ]]; print "PASS unmanaged real core rejects $operation"
done
for operation in install uninstall; do
 rc=0; "$root/Scripts/$operation.sh" >/dev/null 2>&1 || rc=$?
 [[ $rc != 0 ]]; print "PASS unmanaged real core rejects $operation"
done
finish_direct
"$root/Scripts/control.sh" status
print 'PASS live lifecycle complete; service left stopped'
