#!/bin/zsh
# All tracked processes belong to this disposable HOME; never signal a PID alone.
cleanup_tests() {
  local pid stamp current command
  for pid in ${(f)$(jobs -p)}; do
    kill -CONT "$pid" 2>/dev/null || true; kill -TERM "$pid" 2>/dev/null || true
    for i in {1..20}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.05; done
    kill -KILL "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  if [[ -f "$HOME/mock-pid" && -f "$HOME/mock-identity" ]]; then
    pid=$(cat "$HOME/mock-pid"); stamp=$(cat "$HOME/mock-identity")
    current=$(ps -p "$pid" -o lstart= 2>/dev/null) || current=''
    command=$(ps -p "$pid" -o command= 2>/dev/null) || command=''
    if [[ -n $stamp && $stamp == "$current" && $command == *"$HOME/.local/bin/mousescrolltoggle"* ]]; then
      kill -CONT "$pid" 2>/dev/null || true; kill -TERM "$pid" 2>/dev/null || true
      for i in {1..20}; do kill -0 "$pid" 2>/dev/null || break; sleep 0.05; done
      current=$(ps -p "$pid" -o lstart= 2>/dev/null) || current=''
      [[ $current != "$stamp" ]] || kill -KILL "$pid" 2>/dev/null || true
    fi
  fi
  rm -rf "$tmp"
}
trap cleanup_tests EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
