#!/bin/zsh
# Explicit observer only: never starts/stops the service; no samples from an unready PID.
set -euo pipefail
root=${0:A:h:h}
[[ ${1:-} == --live && ${2:-300} == <-> ]] || { print -u2 '用法：measure-performance.sh --live [60..3600秒，10的倍数] [idle|scroll]'; exit 64; }
duration=${2:-300}; mode=${3:-idle}
(( duration >= 60 && duration <= 3600 && duration % 10 == 0 )) || exit 64
[[ $mode == idle || $mode == scroll ]] || exit 64
svc="gui/$(id -u)/local.mousescrolltoggle"
pid_of() { /bin/launchctl print "$svc" | sed -n 's/^[[:space:]]*pid = \([0-9]*\)$/\1/p'; }
"$root/Scripts/control.sh" status >/dev/null
pid=$(pid_of)
print "# mode=$mode pid=$pid warmup=10s interval=10s duration=${duration}s; healthy service required each sample; ps recent CPU and RSS KiB"
sleep 10
print 'seconds,cpu_percent,rss_kib'
for (( elapsed=0; elapsed<=duration; elapsed+=10 )); do
 "$root/Scripts/control.sh" status >/dev/null
 [[ $(pid_of) == "$pid" ]] || { print -u2 '采样终止：实例发生变化'; exit 1; }
 sample=$(ps -p "$pid" -o %cpu=,rss=); values=(${=sample})
 [[ $#values == 2 ]] || exit 1
 print "$elapsed,$values[1],$values[2]"
 (( elapsed == duration )) || sleep 10
done
