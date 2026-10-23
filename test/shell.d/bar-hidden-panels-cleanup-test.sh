#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
require_command jq
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
