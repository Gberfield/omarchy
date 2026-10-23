#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

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
omarchy-shell() {
  case "$2" in
    summon) touch "$HOME/menu-open" ;;
    hide) rm -f "$HOME/menu-open" ;;
  esac
}
wait_until() { :; }
wtype() { [[ ${TEST_FAILURE:-} != "input" ]]; }
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

# An input failure occurs after the menu has mapped but before the ordinary
# hide call. Run the real EXIT trap so cleanup cannot pass by inspecting source.
case_home="$fixture/input-failure"
mkdir -p "$case_home/.local/state/omarchy/toggles"
printf 'right\n' >"$case_home/position"
if HOME="$case_home" TEST_SHELL_PID="$$" TEST_FAILURE=input bash "$fixture/bar-reveal-test.sh" >"$case_home/output" 2>&1; then
  fail "input failure invalidates acceptance"
fi
[[ ! -f $case_home/menu-open ]] || fail "cleanup closes the menu after input failure"
pass "cleanup closes the menu after input failure"
[[ $(cat "$case_home/position") == "right" && ! -f $case_home/.local/state/omarchy/toggles/bar-off ]] ||
  fail "input failure restores original bar settings"
pass "input failure restores original bar settings"

# Failed discovery must clean up the known output even without its inventory.
(
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
cp "$ROOT/test/acceptance.d/bar-hidden-panels-test.sh" "$fixture/bar-hidden-panels-test.sh"
cat >"$fixture/base-test.sh" <<'SH'
ARTIFACTS="$HOME/artifacts"
mkdir -p "$ARTIFACTS"
omarchy-bar() {
  if (( $# == 1 )); then cat "$HOME/position"; else printf '%s\n' "$2" >"$HOME/position"; fi
}
omarchy-toggle-bar() {
  if [[ $1 == "on" ]]; then touch "$HOME/.local/state/omarchy/toggles/bar-off"; else rm -f "$HOME/.local/state/omarchy/toggles/bar-off"; fi
}
quickshell() { printf '[{"pid":%s}]\n' "$TEST_SHELL_PID"; }
omarchy-shell() { :; }
layer_absent() { return 0; }
layer_on_screen() { return 0; }
wtype() { :; }
sleep() { :; }
screenshot() { :; }
pass() { :; }
fail() { exit 1; }
wait_until() {
  local description=$1
  shift 2
  if [[ $description == "temporary monitor appears while bar hidden" ]]; then "$@" || exit 1; fi
}
hyprctl() {
  case "$*" in
    '-j monitors')
      [[ ! -f $HOME/created-name ]] || return 1
      printf '[{"name":"primary","focused":true}]\n'
      ;;
    '-j layers') printf '{"primary":{"levels":{"3":[{"namespace":"omarchy-keyboard-panel","x":0,"y":0,"w":1280,"h":800}]}}}\n' ;;
    'output create headless'*) printf '%s\n' "${4:-HEADLESS-auto}" >"$HOME/created-name" ;;
    'output remove '*) printf '%s\n' "$3" >>"$HOME/removed" ;;
  esac
}
SH
mkdir -p "$fixture/home/.local/state/omarchy/toggles"
printf 'bottom\n' >"$fixture/home/position"
if HOME="$fixture/home" TEST_SHELL_PID="$$" bash "$fixture/bar-hidden-panels-test.sh" >"$fixture/output" 2>&1; then
  fail "monitor discovery failure invalidates the hidden-panel run"
fi
[[ -f $fixture/home/created-name ]] || fail "fault occurs after headless creation" "$(cat "$fixture/output")"
pass "fault occurs after headless creation"
[[ -f $fixture/home/removed && $(cat "$fixture/home/removed") == "$(cat "$fixture/home/created-name")" ]] ||
  fail "discovery failure removes exactly the output the test created"
pass "discovery failure removes exactly the output the test created"
[[ $(cat "$fixture/home/position") == "bottom" ]] || fail "discovery failure restores the original bar edge"
pass "discovery failure restores the original bar edge"
[[ ! -f $fixture/home/.local/state/omarchy/toggles/bar-off ]] || fail "discovery failure restores shown visibility"
pass "discovery failure restores shown visibility"
)
