#!/bin/zsh
set -euo pipefail
umask 077
root=${0:A:h:h}
cfg="$HOME/.config/mousescrolltoggle"
bin="$HOME/.local/bin/mousescrolltoggle"
logs="$HOME/Library/Logs/MouseScrollToggle"
label=local.mousescrolltoggle
if [[ ${MST_TEST_MODE:-} == 1 ]]; then label=${MST_TEST_LABEL:-$label}; fi
domain="gui/$(id -u)"
svc="$domain/$label"
# Test adapters are only enabled explicitly; tests use a disposable HOME.
ctl=/bin/launchctl
if [[ ${MST_TEST_MODE:-} == 1 ]]; then ctl=${MST_TEST_CTL:?}; fi
fail() { print -u2 -- "错误：$1"; exit ${2:-1}; }
mkdir -p "$cfg"
chmod 700 "$cfg"
[[ ! -L "$cfg" ]] || fail '配置目录不能是符号链接' 78
zmodload zsh/system
# Persistent inode: never unlink a lock that another waiter may have opened.
[[ ! -L "$cfg/control.lock" ]] || fail '控制锁不能是符号链接' 78
: >> "$cfg/control.lock"
zsystem flock -t 10 -f lockfd "$cfg/control.lock" || fail '操作锁超时（10 秒），请稍后重试' 75
loaded() {
  if "$ctl" print "$svc" >"$cfg/service.txt" 2>/dev/null; then return 0; fi
  if [[ ${MST_TEST_MODE:-} != 1 ]]; then
    "$ctl" print "$domain" >/dev/null 2>&1 || { print -u2 '错误：无法访问图形用户服务域'; return 2; }
  fi
  return 1
}
health() {
  loaded || return 1
  local pid=$(sed -n 's/^[[:space:]]*pid = \([0-9]*\)$/\1/p' "$cfg/service.txt")
  [[ $pid == <-> ]] || return 1
  /usr/bin/grep -Fq -- "$bin" "$cfg/service.txt" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ $(cat "$cfg/ready-pid" 2>/dev/null) == "$pid" ]] || return 1
  local nonce=$(uuidgen) reply
  print -r -- "$nonce" > "$cfg/request"
  "$ctl" kill SIGUSR1 "$svc" 2>/dev/null || return 1
  for i in {1..20}; do
    reply=$(cat "$cfg/response" 2>/dev/null) || reply=''
    [[ $reply == "$pid READY $nonce" ]] && return 0
    sleep 0.05
  done
  return 1
}
state() {
  local rc=0
  loaded || rc=$?
  if (( rc == 2 )); then print 'ERROR 无法查询服务域'; return 1; fi
  if (( rc == 1 )) && ! core_guard; then print 'ERROR 未托管核心锁被占用，请关闭前台实例'; return 1; fi
  if [[ ! -e "$bin" && ! -e "$cfg/agent.plist" ]]; then print 'NOT_INSTALLED 未安装'; return 3; fi
  if [[ ! -x "$bin" || ! -f "$cfg/agent.plist" || ! -f "$cfg/version" || ! -f "$cfg/source.sha256" ]]; then print 'ERROR 安装不完整'; return 1; fi
  if (( rc == 1 )); then print 'STOPPED 已停止'; return 0; fi
  if health; then print 'RUNNING Event Tap 已启用'; return 0; fi
  print 'ERROR 服务已加载但核心未就绪、权限缺失或 Tap 不健康'; return 1
}
# POSIX record locks, shared with Swift lockf. Keep ownership through mutations.
core_guard() {
  [[ ${corefd:-} != '' ]] && return 0
  [[ ! -L "$cfg/core.lock" ]] || { print -u2 '错误：核心锁不能是符号链接'; return 1; }
  : >> "$cfg/core.lock"
  zsystem flock -t 0 -f corefd "$cfg/core.lock" 2>/dev/null
}
release_core() {
  if [[ ${corefd:-} != '' ]]; then zsystem flock -u "$corefd"; unset corefd; fi
}
require_idle() {
  core_guard && return 0
  print -u2 '错误：核心锁被占用，请关闭前台/未托管核心实例后重试；未停止、删除或替换文件'
  return 1
}
stop_service() {
  local rc=0
  loaded || rc=$?
  (( rc != 2 )) || return 1
  if (( rc == 0 )); then
    "$ctl" bootout "$svc" || { print -u2 '错误：launchctl 卸载失败'; return 1; }
    for i in {1..50}; do
      rc=0; loaded || rc=$?
      (( rc != 2 )) || return 1
      if (( rc == 1 )) && core_guard; then return 0; fi
      sleep 0.1
    done
    print -u2 '错误：停止超时，服务或核心锁仍活跃'
    return 1
  fi
  require_idle
}
start_service() {
  [[ -x "$bin" && -f "$cfg/agent.plist" ]] || { print -u2 '错误：尚未完整安装'; return 3; }
  local rc=0
  loaded || rc=$?
  (( rc != 2 )) || return 1
  if health; then print 'RUNNING Event Tap 已启用'; return; fi
  if loaded; then stop_service || return 1; else require_idle || return 1; fi
  release_core
  "$ctl" bootstrap "$domain" "$cfg/agent.plist" || { print -u2 '错误：launchctl bootstrap 失败，请确认处于图形用户会话'; return 1; }
  for i in {1..5}; do
    if health; then print 'RUNNING Event Tap 已启用'; return; fi
    sleep 0.2
  done
  print -u2 '启动失败：核心未就绪，请检查辅助功能权限和日志（服务保留以供诊断）'
  tail -c 4096 "$logs/stderr.log" >&2 2>/dev/null || true
  return 1
}

restore_files() {
  local backup=$1 f target
  for f in binary agent.plist version source.sha256 managed.sha256 bundle.sha256; do
    target="$cfg/$f"; [[ $f != binary ]] || target=$bin
    if [[ ${MST_TEST_MODE:-} == 1 && ${MST_TEST_RESTORE_FAIL:-} == "$f" ]]; then
      print -u2 "错误：测试注入恢复失败：$f"; return 1
    fi
    if [[ -e "$backup/old-$f" ]]; then
      cp -p "$backup/old-$f" "$target.restore" && mv "$target.restore" "$target" || return 1
    else
      rm -f "$target" || return 1
    fi
  done
}

assert_no_transaction() {
  local pending=("$cfg"/.install.*/phase(N))
  local recovery
  if (( $#pending )); then
    recovery="${pending[1]:h}/recover.sh"
    print -r -u2 -- "错误：存在未完成事务，禁止叠加更新。请先恢复：/bin/zsh ${(q)recovery}"
    return 1
  fi
}
