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
[[ ! -L "$cfg" ]] || fail '配置目录不能是符号链接' 78
mkdir -p "$cfg" || fail '配置目录无法创建，请检查目录权限' 78
chmod 700 "$cfg" || fail '配置目录权限无法设置' 78
zmodload zsh/system
# Persistent inode: never unlink a lock that another waiter may have opened.
[[ ! -L "$cfg/control.lock" ]] || fail '控制锁不能是符号链接' 78
: >> "$cfg/control.lock"
zsystem flock -t 10 -f lockfd "$cfg/control.lock" || fail '操作锁超时（10 秒），请稍后重试' 75
source "${${(%):-%x}:A:h}/runtime.sh"
