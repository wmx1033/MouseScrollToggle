#!/bin/zsh
# A diagnostic snapshot; never bootstrap, bootout, compile or request permission.
set -euo pipefail
umask 077
[[ $# == 0 || ${1:-} == --full-paths || ${1:-} == --redact ]] || { print -u2 '用法：doctor.sh [--redact|--full-paths]'; exit 64; }
root=${0:A:h:h}
cfg="$HOME/.config/mousescrolltoggle"
bin="$HOME/.local/bin/mousescrolltoggle"
logs="$HOME/Library/Logs/MouseScrollToggle"
label=local.mousescrolltoggle
ctl=/bin/launchctl
if [[ ${MST_TEST_MODE:-} == 1 ]]; then label=${MST_TEST_LABEL:?}; ctl=${MST_TEST_CTL:?}; fi
domain="gui/$(id -u)"; svc="$domain/$label"
source "${0:A:h}/runtime.sh"
# Bound protocol/tool probes as well as Tap challenges. Temp output is private.
probe_dir=$(mktemp -d)
probe_pid=''
trap 'if [[ -n $probe_pid ]]; then kill -KILL "$probe_pid" 2>/dev/null || true; wait "$probe_pid" 2>/dev/null || true; fi; rm -rf "$probe_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
probe() {
  local rc=0 finished=0
  "$@" > "$probe_dir/out" 2>/dev/null & probe_pid=$!
  for i in {1..40}; do
    if ! kill -0 "$probe_pid" 2>/dev/null; then finished=1; break; fi
    sleep 0.05
  done
  if (( ! finished )); then
    kill -KILL "$probe_pid" 2>/dev/null || true
    wait "$probe_pid" 2>/dev/null || true
    probe_pid=''; return 124
  fi
  wait "$probe_pid" || rc=$?
  probe_pid=''
  head -c 512 "$probe_dir/out"
  return $rc
}
print 'MouseScrollToggle Diagnostics'
if [[ ! -e "$bin" && ! -e "$cfg/agent.plist" ]]; then print 'INSTALLATION=NOT_INSTALLED'
elif [[ -x "$bin" && -f "$cfg/agent.plist" && -f "$cfg/version" && -f "$cfg/source.sha256" ]]; then print 'INSTALLATION=PRESENT'
else print 'INSTALLATION=INCOMPLETE 请检查二进制/plist/版本/源码摘要'; fi
if [[ $(uname -s) == Darwin ]]; then print "OS=$(sw_vers -productVersion) build=$(sw_vers -buildVersion)"; else print 'OS=NOT_SUPPORTED 非 macOS'; fi
print "ARCH=$(uname -m)"
if xcode-select -p >/dev/null 2>&1 && compiler=$(xcrun --find swiftc 2>/dev/null); then
  compiler_version=$(probe "$compiler" --version | head -1) || compiler_version=UNKNOWN
  print -r -- "SWIFT=$compiler_version"
else print 'SWIFT=UNAVAILABLE 请安装 Xcode Command Line Tools'; fi
if [[ -x "$bin" ]]; then
  print 'BINARY=PRESENT'
  protocol=$(probe "$bin" --version) || protocol=UNKNOWN
  print -r -- "PROTOCOL=$protocol"
  rc=0; probe "$bin" --check-permission >/dev/null || rc=$?
  case $rc in
    0) print 'PERMISSION=AUTHORIZED 当前调用上下文已授权；服务仍需独立 Tap 健康确认' ;;
    2) print 'PERMISSION=DENIED 未授权：系统设置 → 隐私与安全性 → 辅助功能' ;;
    *) print 'PERMISSION=UNKNOWN 无法通过核心检查' ;;
  esac
else print 'BINARY=ABSENT'; print 'PROTOCOL=UNKNOWN 无可执行核心'; print 'PERMISSION=UNKNOWN 无核心，未探测权限'; fi
if [[ -f "$cfg/version" ]]; then print -r -- "VERSION=$(head -c 128 "$cfg/version")"; else print 'VERSION=UNKNOWN 无版本记录'; fi
# Do not create installation directories or lock files when absent.
can_health=0
if [[ -f "$cfg/control.lock" && ! -L "$cfg/control.lock" ]]; then
  zmodload zsh/system
  zsystem flock -t 10 -f lockfd "$cfg/control.lock" || { print -u2 '诊断忙碌：控制锁等待超时'; exit 75; }
  can_health=1
fi
service=''
if [[ ! -x "$ctl" ]]; then
  print 'SERVICE=NOT_SUPPORTED 无 launchctl'; print 'PROCESS=UNKNOWN'; print 'TAP=UNKNOWN'
elif service=$("$ctl" print "$svc" 2>/dev/null); then
  print 'SERVICE=LOADED'
  pid=$(print -r -- "$service" | sed -n 's/^[[:space:]]*pid = \([0-9]*\)$/\1/p')
  if [[ $pid == <-> ]] && kill -0 "$pid" 2>/dev/null; then print "PROCESS=ALIVE pid=$pid"; else print 'PROCESS=NOT_RUNNING'; fi
  if (( can_health )); then
    if health; then print 'TAP=HEALTHY 本次挑战通过'; else print 'TAP=ERROR 服务已加载但未通过实时健康检查'; fi
  else print 'TAP=UNKNOWN 缺少控制锁，跳过挑战'; fi
else
  if [[ ${MST_TEST_MODE:-} == 1 ]] || "$ctl" print "$domain" >/dev/null 2>&1; then
    print 'SERVICE=NOT_LOADED'; print 'PROCESS=NOT_MANAGED'; print 'TAP=NOT_RUNNING 未托管实例的 Tap 状态未知'
  else print 'SERVICE=UNKNOWN 无法访问 gui 用户域'; print 'PROCESS=UNKNOWN'; print 'TAP=UNKNOWN'; fi
fi
if [[ -f "$cfg/core.lock" && ! -L "$cfg/core.lock" ]]; then
  zmodload zsh/system
  if zsystem flock -t 0 -f probe "$cfg/core.lock" 2>/dev/null; then
    print 'CORE_LOCK=FREE'; zsystem flock -u "$probe"
  elif [[ -n $service ]]; then print 'CORE_LOCK=BUSY 服务存在，无法仅凭锁确定持有者'
  else print 'CORE_LOCK=UNMANAGED_BUSY 请关闭前台实例；不向旧 PID 发信号'; fi
else print 'CORE_LOCK=UNKNOWN 无锁文件或不安全路径'; fi
pending=("$cfg"/.install.*/phase(N))
print "TRANSACTIONS=$#pending"
for phase in $pending; do
  print -r -- "RECOVERY=未完成阶段 $(head -c 64 "$phase")"
  if [[ ${1:-} == --full-paths ]]; then recovery="${phase:h}/recover.sh"; else recovery="~/.config/mousescrolltoggle/${phase:h:t}/recover.sh"; fi
  if [[ ${1:-} == --full-paths ]]; then print -r -- "恢复：/bin/zsh ${(q)recovery}"; else print -r -- "恢复：/bin/zsh ${recovery}（可执行转义命令请用 --full-paths）"; fi
done
if [[ ${1:-} == --full-paths ]]; then print -r -- "LOGS=$logs"; else print 'LOGS=~/Library/Logs/MouseScrollToggle/{stdout,stderr}.log'; fi
print 'NOTE=只读快照；已加载服务的检查可能写入 service.txt/request/response 并发送服务级 SIGUSR1；不创建 Tap、不授权、不启停。'
