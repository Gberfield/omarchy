#!/bin/bash
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
run_node_test <<'JS'
const fs = require('fs')
const vm = require('vm')
const api = fs.readFileSync(root + '/shell/Ui/PluginBarApi.qml', 'utf8')
const start = api.indexOf('  function panelWindowFor(')
assert(start >= 0, 'third-party bar facade exposes logical panel window lookup')
const end = api.indexOf('\n  }', start)
const widget = {}, window = {screen:{name:'test'}}
const context = {_panelWindowFor: target => target === widget ? window : null}
vm.createContext(context)
vm.runInContext(api.slice(start, end + 4), context)
assertEqual(context.panelWindowFor(widget), window, 'facade delegates its widget window')
assertEqual(context.panelWindowFor({}), null, 'unknown widget has no logical window')
context._panelWindowFor = null
assertEqual(context.panelWindowFor(widget), null, 'detached facade has no stale window')
const bar = fs.readFileSync(root + '/shell/plugins/bar/Bar.qml', 'utf8')
const callback = bar.match(/_panelWindowFor: function\(widget\) \{([\s\S]*?)\n      \},/)
assert(!!callback, 'bar wires a scoped logical-window callback')
const own = {}, foreign = {}, logical = {}
const scoped = {moduleName:'user.test',root:{moduleWidgets:id=>id==='user.test'?[own]:[],panelWindowFor:target=>logical}}
vm.createContext(scoped)
vm.runInContext('function lookup(widget) {' + callback[1] + '\n}', scoped)
assertEqual(scoped.lookup(own), logical, 'plugin can resolve its own live widget')
assertEqual(scoped.lookup(foreign), null, 'plugin cannot resolve a foreign widget')
scoped.root.moduleWidgets = () => []
assertEqual(scoped.lookup(own), null, 'removed widget cannot retain a logical window')
JS
