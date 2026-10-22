#!/bin/bash

source "$(dirname "$0")/base-test.sh"

require_command jq

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cp "$ROOT/test/acceptance.d/bar-reveal-test.sh" "$fixture/bar-reveal-test.sh"

# Run the actual acceptance script until the shell changes during its first
# wait. Only desktop commands are substituted; the trap, process guard and
# persistent fixture files are real. Never connect to the host compositor.
cat >"$fixture/base-test.sh" <<'SH'
ARTIFACTS="$HOME/artifacts"
mkdir -p "$ARTIFACTS"
omarchy-bar() {
  [[ $1 == "position" ]] || return 1
  if (( $# == 1 )); then
    cat "$HOME/position"
  else
    printf '%s\n' "$2" >"$HOME/position"
  fi
}
omarchy-toggle-bar() {
  case $1 in
    on) touch "$HOME/.local/state/omarchy/toggles/bar-off" ;;
    off) rm -f "$HOME/.local/state/omarchy/toggles/bar-off" ;;
    *) return 1 ;;
  esac
}
quickshell() {
  if [[ ! -f $HOME/queried ]]; then
    touch "$HOME/queried"
    printf '[{"pid":%s}]\n' "$TEST_SHELL_PID"
  else
    # The original /proc identity still exists, but this shell no longer serves
    # the selected config. The acceptance run must fail, then restore settings.
    printf '[]\n'
  fi
}
layer_absent() { return 1; }
omarchy-shell() { :; }
wait_until() { :; }
wtype() { :; }
hyprctl() { printf '{}\n'; }
screenshot() { touch "$HOME/unexpected-capture"; }
fail() { exit 1; }
SH

for visibility in shown hidden; do
  case_home="$fixture/$visibility"
  mkdir -p "$case_home/.local/state/omarchy/toggles"
  printf 'bottom\n' >"$case_home/position"
  if [[ $visibility == "hidden" ]]; then
    touch "$case_home/.local/state/omarchy/toggles/bar-off"
  fi

  if HOME="$case_home" TEST_SHELL_PID="$$" bash "$fixture/bar-reveal-test.sh" >"$case_home/output" 2>&1; then
    fail "shell change invalidates the $visibility acceptance run"
  fi
  grep -Fq 'shell identity changed' "$case_home/output" ||
    fail "the $visibility run reaches the shell-change guard" "$(cat "$case_home/output")"
  pass "shell change invalidates the $visibility acceptance run"

  [[ $(cat "$case_home/position") == "bottom" ]] ||
    fail "cleanup restores position after a shell change with bar $visibility"
  pass "cleanup restores position after a shell change with bar $visibility"

  if [[ $visibility == "hidden" ]]; then
    [[ -f $case_home/.local/state/omarchy/toggles/bar-off ]] ||
      fail "cleanup restores originally hidden visibility"
  else
    [[ ! -f $case_home/.local/state/omarchy/toggles/bar-off ]] ||
      fail "cleanup restores originally shown visibility"
  fi
  pass "cleanup restores originally $visibility visibility"

  [[ ! -e $case_home/unexpected-capture ]] ||
    fail "shell change is recorded without a recovery capture"
  grep -Fq 'invalidated by shell change' "$case_home/artifacts/bar-reveal.jsonl" ||
    fail "shell-change failure evidence survives cleanup"
  pass "shell-change evidence survives cleanup without a capture ($visibility)"
done
