#!/bin/zsh
source "${0:A:h}/common.sh"
stop_service || exit $?
if [[ -e "$cfg/agent.plist" ]]; then
  [[ -f "$cfg/managed.sha256" && $(shasum -a 256 "$cfg/agent.plist" | cut -d ' ' -f1) == $(cat "$cfg/managed.sha256") ]] || fail '配置已修改：服务已停止，请备份并移走 agent.plist 后重试卸载' 78
fi
rm -f "$bin"
for f in agent.plist version source.sha256 managed.sha256 request response ready-pid service.txt; do rm -f "$cfg/$f"; done
for f in stdout.log stderr.log; do rm -f "$logs/$f"; done
rmdir "$logs" 2>/dev/null || true
print 'NOT_INSTALLED 已卸载（保留锁文件以保护并发操作，保留未知文件）'
