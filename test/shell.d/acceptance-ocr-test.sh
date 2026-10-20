#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir "$work/bin"
export OMARCHY_ACCEPTANCE_DIR="$work/artifacts"
export PATH="$work/bin:$PATH"

# Model the observed OCR segmentation at the external capture/OCR boundary.
# The acceptance helper, its pipelines, and its matching remain real Bash.
cat > "$work/bin/grim" <<'FIXTURE'
#!/bin/bash
[[ ${CAPTURE_FAIL:-0} == 0 ]] || exit 1
scale=1
if [[ ${1:-} == "-s" ]]; then scale=$2; shift 2; fi
printf '%s' "$scale" > "$1"
FIXTURE
cat > "$work/bin/tesseract" <<'FIXTURE'
#!/bin/bash
[[ ${OCR_FAIL:-0} == 0 ]] || exit 1
if [[ $(cat "$1") == 2 ]]; then
  printf 'SAN\nFRANCISCO\nWIND\nSmall caption\n'
else
  printf 'SAN FRANCISCO\n'
fi
FIXTURE
chmod +x "$work/bin/grim" "$work/bin/tesseract"

# shellcheck source=../acceptance.d/base-test.sh
source "$ROOT/test/acceptance.d/base-test.sh"

# A real 2x Weather capture puts SAN and FRANCISCO on separate OCR lines,
# while native resolution recognizes the full visible label on one line.
screen_contains "SAN FRANCISCO" || fail "native OCR finds a visible multiword label split by scaled OCR"
pass "native OCR finds a visible multiword label split by scaled OCR"

screen_contains "Small caption" || fail "scaled OCR still finds small captions absent from native OCR"
pass "scaled OCR still finds small captions absent from native OCR"

if screen_contains "San Diego"; then
  fail "missing text fails at both capture resolutions"
fi
pass "missing text fails at both capture resolutions"

if CAPTURE_FAIL=1 screen_contains "SAN FRANCISCO"; then
  fail "failed captures never reuse a previous image"
fi
pass "failed captures never reuse a previous image"

if OCR_FAIL=1 screen_contains "SAN FRANCISCO"; then
  fail "OCR errors do not pass a text assertion"
fi
pass "OCR errors do not pass a text assertion"

[[ ! -e /tmp/omarchy-acceptance-ocr-$$.png ]] || fail "OCR capture is removed after success and failure"
pass "OCR capture is removed after success and failure"
