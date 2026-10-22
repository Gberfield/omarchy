#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const vm = require('vm')
const source = fs.readFileSync(root + '/shell/plugins/bar/Bar.qml', 'utf8')
const names = ['targetWindow', 'slotWindow', 'panelWindowFor']
const functions = names.map(name => {
  const start = source.indexOf(`  function ${name}(`)
  assert(start >= 0, `bar exposes ${name}`)
  const end = source.indexOf('\n  }', start)
  return source.slice(start, end + 4)
}).join('\n')
const audio = {}, bluetooth = {}, removed = {}
const primary = { screen: { name: 'primary' } }
const secondary = { screen: { name: 'secondary' } }
// No QsWindow attached backing window exists after hide. The module slots
// still own their per-output logical windows and live widgets.
const context = {
  moduleSlots: [
    { activeItem: audio, window: primary },
    { activeItem: bluetooth, window: secondary }
  ]
}
vm.createContext(context)
vm.runInContext(functions, context)
assertEqual(context.panelWindowFor(audio), primary, 'hidden Audio retains its primary output')
assertEqual(context.panelWindowFor(bluetooth), secondary, 'hidden Bluetooth retains its secondary output')
context.moduleSlots[0].window = secondary
assertEqual(context.panelWindowFor(audio), secondary, 'moving a widget updates its panel output')
context.moduleSlots = context.moduleSlots.filter(slot => slot.activeItem !== bluetooth)
assertEqual(context.panelWindowFor(bluetooth), null, 'removed output does not retain a stale panel window')
assertEqual(context.panelWindowFor(removed), null, 'unknown widget has no panel window')
assertEqual(context.panelWindowFor(null), null, 'missing widget has no panel window')
const attached = { QsWindow: { window: primary } }
assertEqual(context.slotWindow({ activeItem: attached }), primary, 'attached window remains a fallback for slots without an explicit window')
JS
