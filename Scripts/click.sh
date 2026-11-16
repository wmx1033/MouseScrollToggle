#!/bin/zsh
source "${0:A:h}/common.sh"
source "$root/Scripts/manifest.sh"
source "$root/Scripts/installer.sh"
[[ $(uname -s) == Darwin ]] || fail '仅支持 macOS' 78
[[ $(uname -m) == arm64 || $(uname -m) == x86_64 ]] || fail '不支持此处理器架构' 78
rc=0; loaded || rc=$?
(( rc != 2 )) || exit 1
assert_no_transaction || exit 1
# Snapshot the click intent before updates; a running service update must end OFF.
was_healthy=0
if health; then was_healthy=1; fi
if (( rc == 1 )); then require_idle || exit 1; release_core; fi
incoming=$(cat "$root/VERSION")
# Numeric release versions only. Legacy Phase 2 dev marker can migrate once.
version_number() {
  local v=$1 parts
  [[ $v == <->.<->.<-> ]] || return 1
  parts=(${(s:.:)v})
  (( parts[1] < 1000 && parts[2] < 1000 && parts[3] < 1000 )) || return 1
  print $(( 10#${parts[1]} * 1000000 + 10#${parts[2]} * 1000 + 10#${parts[3]} ))
}
new_number=$(version_number "$incoming") || fail '载荷版本格式无效' 78
if [[ -f "$cfg/version" ]]; then
  installed=$(cat "$cfg/version")
  if [[ $installed != 1.0.0-dev || -e "$cfg/bundle.sha256" ]]; then
    old_number=$(version_number "$installed") || fail '本地版本无法比较，请先备份并检查 version 文件' 78
    (( new_number >= old_number )) || fail "旧载荷拒绝降级：本地 $installed，载荷 $incoming；请使用最新快捷指令" 78
  fi
fi
current_bundle=$(bundle_hash)
if [[ -f "$cfg/bundle.sha256" && $incoming == ${installed:-} && $(cat "$cfg/bundle.sha256") != $current_bundle ]]; then
  print -u2 '提示：同版本载荷内容发生变化，将更新控制逻辑；发布新版时应递增 VERSION'
fi
# Always run the same installer: configuration checks and hash-based no-op compile
# remain authoritative. Current embedded scripts apply even if Swift is unchanged.
MST_VERSION=$incoming
if (( was_healthy )); then restore_running=0; else restore_running=1; fi
# Plain call preserves errexit inside the installation subshell.
install_main "$restore_running" >&2
if (( was_healthy )); then
  stop_service >&2 || exit $?
  state > "$cfg/click-final" || fail '关闭后最终状态验证失败'
  [[ $(cat "$cfg/click-final") == STOPPED* ]] || fail '关闭后状态不符'
  print '鼠标滚轮反转：已关闭'
else
  start_service >&2 || exit $?
  health || fail '最终健康验证失败，请检查辅助功能权限后重试'
  print '鼠标滚轮反转：已开启'
fi
