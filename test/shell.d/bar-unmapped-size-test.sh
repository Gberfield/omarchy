#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
run_node_test <<'JS'
const fs = require('fs')
const source = fs.readFileSync(root + '/shell/plugins/bar/Bar.qml', 'utf8')
const panel = source.slice(source.indexOf('  component BarPanel: PanelWindow {'),source.indexOf('    color:',source.indexOf('  component BarPanel: PanelWindow {')))
function dimensions(vertical, screen) {
  const context = {root:{vertical},screen,thickness:26}
  const vm = require('vm');vm.createContext(context)
  return ['Width','Height'].map(axis => {
    const expression = panel.match(new RegExp('implicit'+axis+': (.*)'))[1]
    return vm.runInContext(expression,context)
  })
}
for (const vertical of [false,true]) {
  const actual = dimensions(vertical,{width:1280,height:800})
  assertEqual(actual[0],vertical?26:1280,'unmapped bar has its logical width for '+(vertical?'vertical':'horizontal')+' edge')
  assertEqual(actual[1],vertical?800:26,'unmapped bar has its logical height for '+(vertical?'vertical':'horizontal')+' edge')
}
assertEqual(dimensions(true,{width:1920,height:1080})[1],1080,'new monitor provides vertical layout extent before first map')
JS
