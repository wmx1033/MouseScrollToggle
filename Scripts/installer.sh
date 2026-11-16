#!/bin/zsh
# Internal function; caller owns control.lock. Subshell confines EXIT cleanup.
install_main() (
# 0: successful update stays stopped for an OFF click; rollback still restores old service.
local restore_running=${1:-1}
[[ $(id -u) != 0 ]] || fail '请以普通用户安装，不使用 sudo' 78
mkdir -p "${bin:h}" "$logs"
for f in "$bin" "$cfg/agent.plist" "$cfg/version" "$cfg/source.sha256" "$cfg/managed.sha256" "$cfg/bundle.sha256"; do
  [[ ! -L $f ]] || fail "拒绝符号链接：$f" 78
done
if [[ -e "$cfg/agent.plist" ]]; then
  [[ -f "$cfg/managed.sha256" && $(shasum -a 256 "$cfg/agent.plist" | cut -d ' ' -f1) == $(cat "$cfg/managed.sha256") ]] || fail '配置冲突：请备份并移走 agent.plist 后重试；未覆盖用户配置' 78
fi
assert_no_transaction
tmp=$(mktemp -d "$cfg/.install.XXXXXX")
cleanup=1
trap 'if (( cleanup )); then rm -rf "$tmp"; else print -u2 -- "错误：事务未完成，旧版本备份保留：$tmp"; print -r -u2 -- "恢复命令：/bin/zsh ${(q)tmp}/recover.sh"; fi' EXIT
hash=$(shasum -a 256 "$root/Sources/MouseScrollToggle.swift" | cut -d ' ' -f1)
changed=1
if [[ -x "$bin" && -f "$cfg/source.sha256" && $(cat "$cfg/source.sha256") == $hash ]]; then changed=0; fi
if (( changed )); then
  if [[ ${MST_TEST_MODE:-} == 1 && -n ${MST_TEST_BUILD:-} ]]; then
    "${MST_TEST_BUILD:?}" "$tmp/binary" || fail '临时编译失败，旧安装未改变'
  else
    xcrun swiftc -parse-as-library -O "$root/Sources/MouseScrollToggle.swift" -o "$tmp/binary" || fail '临时编译失败，请安装或检查 Xcode Command Line Tools（xcode-select --install）；旧安装未改变'
  fi
  "$tmp/binary" --version >/dev/null || fail '临时二进制验证失败，旧安装未改变'
fi
# plutil constructs XML with correct escaping, including spaces and XML metacharacters.
plutil -create xml1 "$tmp/agent.plist"
plutil -insert Label -string "$label" "$tmp/agent.plist"
plutil -insert ProgramArguments -json "[]" "$tmp/agent.plist"
plutil -insert ProgramArguments.0 -string "$bin" "$tmp/agent.plist"
plutil -insert RunAtLoad -bool YES "$tmp/agent.plist"
plutil -insert EnvironmentVariables -json '{}' "$tmp/agent.plist"
plutil -insert EnvironmentVariables.HOME -string "$HOME" "$tmp/agent.plist"
plutil -insert StandardOutPath -string "$logs/stdout.log" "$tmp/agent.plist"
plutil -insert StandardErrorPath -string "$logs/stderr.log" "$tmp/agent.plist"
plutil -lint "$tmp/agent.plist" >/dev/null
print -r -- "${MST_VERSION:-$(cat "$root/VERSION")}" > "$tmp/version"
print -r -- "$hash" > "$tmp/source.sha256"
shasum -a 256 "$tmp/agent.plist" | cut -d ' ' -f1 > "$tmp/managed.sha256"
bundle_hash > "$tmp/bundle.sha256"
files=(agent.plist version source.sha256 managed.sha256 bundle.sha256)
for f in $files; do [[ ! -e "$cfg/$f" ]] || cp -p "$cfg/$f" "$tmp/old-$f"; done
[[ ! -e "$bin" ]] || cp -p "$bin" "$tmp/old-binary"
was_loaded=0
rc=0; loaded || rc=$?
(( rc != 2 )) || exit 1
if (( rc == 0 )); then was_loaded=1; fi
# Version-only updates do not interrupt a healthy service.
restart=$changed
if [[ -f "$cfg/agent.plist" ]] && ! cmp -s "$cfg/agent.plist" "$tmp/agent.plist"; then restart=1; fi
# Prepare complete recovery material before touching installed files.
cp "$root/Scripts/common.sh" "$tmp/common.sh"
print -r -- "$was_loaded" > "$tmp/was-loaded"
cat > "$tmp/recover.sh" <<'RECOVER'
#!/bin/zsh
[[ "$HOME" == $(cat "${0:A:h}/expected-home") ]] || { print -u2 '恢复 HOME 不匹配'; exit 1; }
source "${0:A:h}/common.sh"
backup=${0:A:h}
stop_service || exit 1
restore_files "$backup" || { print -u2 "恢复文件失败，备份保留：$backup"; exit 1; }
if [[ $(cat "$backup/was-loaded") == 1 ]]; then
  start_service || { print -u2 "旧服务恢复失败，备份保留：$backup"; exit 1; }
fi
rm -rf "$backup"
print '旧版本已完整恢复'
RECOVER
print -r -- "$HOME" > "$tmp/expected-home"
cleanup=0
print PREPARED > "$tmp/phase"
if (( was_loaded && restart )); then stop_service || exit 1
elif (( ! was_loaded )); then require_idle || exit 1
fi
commit_install() {
  print REPLACING > "$tmp/phase"
  if (( changed )); then chmod 700 "$tmp/binary" || return 1; mv "$tmp/binary" "$bin" || return 1; fi
  for f in $files; do mv "$tmp/$f" "$cfg/$f" || return 1; done
  if (( was_loaded && restart && restore_running )); then start_service || return 1; fi
}
if ! commit_install; then
  print -u2 '更新失败：正在回滚安装产物'
  print ROLLING_BACK > "$tmp/phase"
  stop_service || exit 1
  restore_files "$tmp" || { print -u2 '错误：恢复文件失败，禁止启动不一致安装'; exit 1; }
  if (( was_loaded )); then start_service || { print -u2 '错误：产物已回滚，但旧服务健康恢复失败'; exit 1; }; fi
  cleanup=1
  fail '更新失败，已完整恢复旧安装' 1
fi
# Commit point: files installed; requested running-state policy successfully applied.
print COMMITTED > "$tmp/phase"
cleanup=1
print '安装成功（安装与开启分离；未运行的服务保持停止）'

)
