#!/bin/zsh
source "${0:A:h}/common.sh"
[[ $(id -u) != 0 ]] || fail '请以普通用户安装，不使用 sudo' 78
mkdir -p "${bin:h}" "$logs"
for f in "$bin" "$cfg/agent.plist" "$cfg/version" "$cfg/source.sha256" "$cfg/managed.sha256"; do
  [[ ! -L $f ]] || fail "拒绝符号链接：$f" 78
done
if [[ -e "$cfg/agent.plist" ]]; then
  [[ -f "$cfg/managed.sha256" && $(shasum -a 256 "$cfg/agent.plist" | cut -d ' ' -f1) == $(cat "$cfg/managed.sha256") ]] || fail '配置冲突：请备份并移走 agent.plist 后重试；未覆盖用户配置' 78
fi
tmp=$(mktemp -d "$cfg/.install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
hash=$(shasum -a 256 "$root/Sources/MouseScrollToggle.swift" | cut -d ' ' -f1)
changed=1
if [[ -x "$bin" && -f "$cfg/source.sha256" && $(cat "$cfg/source.sha256") == $hash ]]; then changed=0; fi
if (( changed )); then
  if [[ ${MST_TEST_MODE:-} == 1 ]]; then
    "${MST_TEST_BUILD:?}" "$tmp/binary" || fail '临时编译失败，旧安装未改变'
  else
    xcrun swiftc -parse-as-library -O "$root/Sources/MouseScrollToggle.swift" -o "$tmp/binary" || fail '临时编译失败，请检查 Command Line Tools；旧安装未改变'
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
print -r -- "${MST_VERSION:-1.0.0-dev}" > "$tmp/version"
print -r -- "$hash" > "$tmp/source.sha256"
shasum -a 256 "$tmp/agent.plist" | cut -d ' ' -f1 > "$tmp/managed.sha256"
files=(agent.plist version source.sha256 managed.sha256)
for f in $files; do [[ ! -e "$cfg/$f" ]] || cp -p "$cfg/$f" "$tmp/old-$f"; done
[[ ! -e "$bin" ]] || cp -p "$bin" "$tmp/old-binary"
was_loaded=0
if loaded; then was_loaded=1; fi
# Version-only updates do not interrupt a healthy service.
restart=$changed
if [[ -f "$cfg/agent.plist" ]] && ! cmp -s "$cfg/agent.plist" "$tmp/agent.plist"; then restart=1; fi
if (( was_loaded && restart )); then stop_service; fi
commit_install() {
  if (( changed )); then chmod 700 "$tmp/binary"; mv "$tmp/binary" "$bin" || return 1; fi
  for f in $files; do mv "$tmp/$f" "$cfg/$f" || return 1; done
  if (( was_loaded && restart )); then start_service || return 1; fi
}
if ! commit_install; then
  print -u2 '更新失败：正在回滚安装产物'
  stop_service
  if [[ -e "$tmp/old-binary" ]]; then mv "$tmp/old-binary" "$bin"; else rm -f "$bin"; fi
  for f in $files; do
    if [[ -e "$tmp/old-$f" ]]; then mv "$tmp/old-$f" "$cfg/$f"; else rm -f "$cfg/$f"; fi
  done
  if (( was_loaded )); then start_service || fail '产物已回滚，但旧服务健康恢复失败，请重新授权并 start' 1; fi
  fail '更新失败，已恢复旧安装' 1
fi
print '安装成功（安装与开启分离；未运行的服务保持停止）'
