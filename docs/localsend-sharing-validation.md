# LocalSend sharing validation

The Share menu and CLI now support native LocalSend text messages through a multiline composer or `omarchy share text [message]`. Ordinary clipboard sharing uses LocalSend's native `--text` route without temporary files, aligned with guilhermetk's independently authored #6979. His contribution is credited in the reconciliation commit; his branch is unchanged.

Text and clipboard launches share the existing protected launcher: fixed systemd descriptions keep message contents out of command-derived journal descriptions, environment expansion is disabled, flag-like messages are protected, and the detached service reports LocalSend errors. Clipboard-read failures and file/folder service-launch failures also notify. File/folder selection remains unchanged. LocalSend still receives text in process arguments and trims surrounding whitespace.

The contribution branch now includes quattro at `4e059acff2f4e4c4e5a303ce9bc97223097e45eb`, without rewriting history. English menu and notification catalog entries follow the current translation system. The composer pins GTK/GDK 3 and uses the system Python.

Earlier container validation on October 17, 2026 (before the desk run below):
- Final sharing suite: **21 tests passed without skips**, plus the real menu-parser assertion. Includes privacy, literal/flag-like text, cancellation, clipboard reads, oversized clipboard errors, scheduling and detached child failures, file/folder routes, and catalog-based notifications.
- New real GTK suite: **four scenarios passed under Xvfb**, covering multiline Unicode output, button sensitivity, Ctrl+Enter, Cancel, Escape, and blank Ctrl+Enter. The rendered composer was inspected with entered text. The suite explicitly skips when GTK or a display is unavailable.
- Full CLI suite passed with GNU awk. ShellCheck and Bash syntax checks passed.
- Current upstream catalog structure, reference, placeholder, plural and number checks passed. `extract-scan --check` reports no candidates and no stale catalogs. The complete i18n shell test later fails in the unchanged locale-generator section because this container runs as root and has no installed `/usr/share/omarchy`; this is not a clean full i18n-suite result.
- Released LocalSend **1.18.2** was launched under Xvfb with a synthetic flag-like Unicode message. Its Send view staged native text with the expected **31-byte** trimmed payload. No message was sent to another device; multicast discovery is restricted here.
- The aggregate `./test/all` runner stalled outside sharing. A complete per-file shell sweep with 120-second limits and per-file output logs compared the original and reconciled pre-upstream-sync trees: **322/323 files exercised; the same 69 files failed; no new failing files and no timeouts**. There were skipped checks in 35/36 files; the additional skip is the real GTK suite in the headless sweep, separately run successfully under Xvfb. This comparison is not a claim that the final current-upstream full suite is green.

## Desk validation on October 17, 2026 EDT

Fetched `Gberfield/omarchy:add-share-text` into a new standalone checkout; its starting head was still `a1cd232510813de2e649de96a2c3e8f720fb5832`. Existing checkouts and the installed `/usr/share/omarchy` configuration were not edited. GUI checks used this chat's independent hidden native Sway/Wayland session on desk. This is a real graphical session, but it is not an installed Omarchy/Hyprland acceptance VM.

Versions: LocalSend `1.18.2-1`, GTK `3.24.52-1`, PyGObject `3.56.3-1`, Python `3.14.7`, systemd `261.2-1`, Bash `5.3.15`, GNU awk `5.4.1-1`, Node `26.8.2`, jq `1.8.2`, ShellCheck `0.11.0-137`, and GitHub CLI `2.102.0`.

### Oversized clipboard regression

[Review comment r4305015851](https://github.com/omacom/omarchy/pull/14480#discussion_r4305015851) correctly identified the per-argument limit. A 140 KiB synthetic clipboard reproduced `Argument list too long` against the starting head. The previous test only checked notification on this failure; it did not preserve large clipboard sharing.

Text of at least 64 KiB now uses a private `message.txt` file and LocalSend's existing file route. The threshold counts UTF-8 bytes, leaving headroom below Linux's 128 KiB per-argument limit on 4 KiB-page systems. Smaller messages retain the native `--text` route and its flag protection. The directory is mode 0700, the file is mode 0600, and cleanup occurs after LocalSend exits or service scheduling fails. This fallback applies to composed text, clipboard text, and direct text that reaches the command. A caller still cannot supply an argument larger than the kernel allows to the CLI itself. Command substitution retains its existing removal of trailing newlines; the native LocalSend text route also trims surrounding whitespace. Forced `SIGKILL`, power loss, or a service shell that cannot start can leave a private temporary file behind; normal cleanup is not secure erasure.

The focused suite grew from 21 to **27 tests**, with a failing run against the old implementation before the fix. Coverage includes the oversized clipboard, multibyte threshold, native text below the threshold, oversized composer output, restrictive permissions, exact file contents, and cleanup/notifications for preparation, scheduling, and detached child failures. No changes were made to guilhermetk's branch.

### Commands and results

Run from the isolated repository root:

```bash
bash test/shell.d/share-text-test.sh
OMARCHY_SHARE_GTK_SCREENSHOT=/work/composer-final.png bash test/shell.d/share-text-gtk-test.sh
./test/cli
I18N_STRUCTURAL=1 bash test/shell.d/i18n-test.sh
python3 -B scripts/i18n-sync.py extract-scan --check
OMARCHY_PATH="$PWD" PATH="$PWD/bin:$PATH" bash test/shell.d/notification-send-test.sh
OMARCHY_PATH="$PWD" PATH="$PWD/bin:$PATH" bash test/shell.d/menu-plugin-test.sh
shellcheck -x -P SCRIPTDIR bin/omarchy-menu-share test/shell.d/share-text-test.sh test/shell.d/share-text-gtk-test.sh
bash -n bin/omarchy-menu-share test/shell.d/share-text-test.sh test/shell.d/share-text-gtk-test.sh
git diff --check
```

- **PASS:** 27 sharing tests plus the real Share-menu parser assertion, including a rerun inside the hidden graphical session; no skips.
- **PASS:** all four real GTK scenarios in that Wayland session; no skips. The entered composer screenshot was inspected. GTK accessibility-bus and PyGObject deprecation warnings remain in the logs.
- **PASS:** CLI suite (125 assertions), notification wrapper (17 assertions), plugin picker (12 assertions), ShellCheck, Bash syntax, and whitespace checks.
- **PASS WITH ONE INTENTIONAL SKIP:** structural i18n suite (401 `ok` lines, including the structural-mode translation-completeness skip). This run reaches the locale-generator and sync fixtures that the earlier container run did not complete. It does not prove translation completeness.
- **PASS:** extraction scan reports `candidates: []`, `menuCatalogStale: false`, and `keybindingsCatalogStale: false`.
- **FAIL, outside sharing:** `OMARCHY_PATH="$PWD" PATH="$PWD/bin:$PATH" bash test/shell.d/menu-test.sh` stops at `menu checks Opaque Bar while the bar is opaque`, expected `["opaque"]`, actual `[]`. The standalone `omarchy-bar background` scratch-home probe returns `opaque`; the full menu-test failure is not fixed or counted as passing. Earlier plugin-picker failures caused by the installed environment were resolved by explicitly selecting this checkout's `OMARCHY_PATH` and `PATH`.

### Targeted GUI routes

The production CLI/router, composer, clipboard reader, file/folder dispatch, and packaged LocalSend ran in the hidden desktop. Because that desktop's private bus has no systemd manager, GUI staging used a narrowly scoped `systemd-run` adapter that removes the manager options and executes the production service command in the hidden session. Those GUI checks do **not** prove graphical systemd integration. The actual systemd checks below use desk's real user manager separately, without modifying its environment.

Commands included:

```bash
omarchy share text
omarchy share text --share
omarchy share clipboard
omarchy share file '/work/synthetic folder/synthetic file.txt'
omarchy share folder '/work/synthetic folder'
omarchy share text $' \t\n'
```

- **PASS:** entered `LSVALID café 🌎` followed by a second line containing literal `${HOME}`, `$(touch unwanted)`, quotes, and `--share`; the composer opened LocalSend and staged the expected 62-byte native payload. The CLI `--share` message staged 7 bytes; the synthetic clipboard staged 57 bytes. No `unwanted` file appeared.
- **PASS:** file and folder routes each staged the synthetic 21-byte file. No recipient was selected and nothing was sent to another device.
- **PASS:** whitespace-only direct input and actual composer Escape cancellation returned zero without calling the launch adapter. The GTK suite separately verifies whitespace button sensitivity, blank Ctrl+Enter, Ctrl+Enter acceptance, Cancel, and Escape.
- **PASS:** the updated oversized clipboard route staged a synthetic 204 KB file in packaged LocalSend. Its content was synthetic multiline Unicode with literal shell-like text. The private file/directory cleanup and clipboard restoration were checked after ending the owned validation app.
- **LIMITED:** the actual menu plugin configuration loads, but its overlay requires Hyprland monitor IPC. This Sway session cannot render it; parser/routing tests pass, while installed Share-menu clicks remain a VM acceptance gap. No production overlay was patched or replaced.
- **LIMITED:** actual portal file/folder picker interaction remains unexecuted; explicit file/folder arguments and automated picker selection/cancellation/failure fixtures were exercised.
- **LIMITED:** LocalSend logs missing private system-bus/NetworkManager access, GTK warnings, an existing-instance HTTP 403, and discovery/listener address-in-use warnings. Staging is observed; discovery, reception, and transmission are not accepted by these checks. An automatic safety review rejected an intended Edit-control click as insufficiently identified; that inspection was left unexecuted.

Only synthetic data was placed in the hidden clipboard. Its prior selection was absent and was restored to absent; the host clipboard was not read or changed.

### Real systemd and notifications

The local probe command was:

```bash
dbus-run-session -- python3 -B ../evidence/notification-receiver.py
```

This launches `../evidence/systemd_validation.py`, which invokes the real `bin/omarchy-menu-share` through `/usr/bin/systemd-run` on desk's actual user manager. Per-service `--setenv` values select controlled LocalSend/clipboard fixtures and a private notification receiver; the manager environment and installed services are unchanged. The probe's source, per-unit JSON journal records, arguments, notifications, and results are retained beside the isolated checkout under `../evidence/`, not committed as raw host journal metadata.

**PASS: 13 cases.** These cover literal multiline Unicode and shell-like direct/clipboard arguments, flag-like text, file/folder arguments, detached status-7 failure, actual packaged LocalSend failure with an isolated nonexistent display (status 1), oversized clipboard success/failure, and four real scheduling rejections using an already-active uniquely named validation unit. All validation units were stopped/reset by exact owned name. **Seven critical notifications** reached a private real D-Bus receiver through the production `omarchy-notification-send`/`busctl` implementation, with the expected catalog summaries/bodies and urgency 2. This verifies delivery, not installed-shell toast rendering.

For text/clipboard cases, manager journal `MESSAGE` fields used the fixed `Share text with LocalSend` description; none contained the synthetic `LSVALID-` markers. Literal `${HOME}` and shell-like strings reached the controlled child unchanged. File/folder paths still appear in their existing command-derived descriptions.

**Privacy limit confirmed live:** the actual LocalSend startup failure logged `cannot open display`, and that application's structured journal entry included the synthetic message in `_CMDLINE`. Fixed descriptions protect systemd's command-derived start/stop text; they do not prevent process-argument exposure or journal metadata recording it. The source comment now states this narrower guarantee. Oversized fallback contents are file data rather than arguments, but that file remains readable to its owner while staged.

The first notification probe sampled before the service had finished; its failed witness is retained, and the probe now waits for terminal manager state. An initial oversized-probe expectation also included trailing newlines that the pre-existing clipboard command substitution removes; the corrected expectation follows that existing behavior. Neither probe correction is a production fix.

## Remaining acceptance gaps

- **NOT RUN:** full graphical acceptance in a disposable installed Omarchy VM. The current chat has no running contained VM supervisor, and the expected local `omarchy-iso` checkout/ISO harness was unavailable. No full acceptance command was run on desk. Follow `agents/skills/acceptance-tests.md` with `--sync-all ../omarchy` when the disposable harness is available; installed Share-menu/portal-picker interaction and rendered notification toasts remain part of that gap.
- **ACTION REQUIRED upstream:** the exact starting-head translation workflow [run 39080813299](https://github.com/omacom/omarchy/actions/runs/39080813299) reports `completed` / `action_required` with **zero jobs**. Local structural checks passing is not an Actions pass. An upstream maintainer must approve eligible workflow execution; no approval control was bypassed. Check the latest head run after each push; this historical run is not a result for a later commit.
- **NOT AUTHORIZED / NOT RUN:** sending to another device. No transmission or reception acceptance is claimed.

Neither PR has been merged.

<details>
<summary>69 shell-test files failing on both original and reconciled trees in this environment</summary>

- `test/shell.d/agent-account-exec-test.sh`
- `test/shell.d/agent-account-test.sh`
- `test/shell.d/ascii-test.sh`
- `test/shell.d/bar-text-color-test.sh`
- `test/shell.d/browser-handoff-test.sh`
- `test/shell.d/browser-policy-dir-test.sh`
- `test/shell.d/channel-sudo-boundary-test.sh`
- `test/shell.d/channel-test.sh`
- `test/shell.d/clipboard-test.sh`
- `test/shell.d/config-test.sh`
- `test/shell.d/default-agent-test.sh`
- `test/shell.d/default-apps-test.sh`
- `test/shell.d/dev-link-test.sh`
- `test/shell.d/dev-unlink-test.sh`
- `test/shell.d/elsewhen-greetings-test.sh`
- `test/shell.d/elsewhen-model-test.sh`
- `test/shell.d/factory-reset-accounts-test.sh`
- `test/shell.d/hermes-cli-test.sh`
- `test/shell.d/hermes-desktop-install-test.sh`
- `test/shell.d/hermes-remove-test.sh`
- `test/shell.d/hw-hybrid-gpu-test.sh`
- `test/shell.d/hw-nvidia-test.sh`
- `test/shell.d/hyprland-binding-conflicts-test.sh`
- `test/shell.d/hyprland-default-config-test.sh`
- `test/shell.d/hyprland-keyboard-layout-test.sh`
- `test/shell.d/hyprland-paths-test.sh`
- `test/shell.d/hyprland-qconsole-test.sh`
- `test/shell.d/hyprland-shutdown-test.sh`
- `test/shell.d/hyprland-startup-cursor-test.sh`
- `test/shell.d/hyprland-workspace-layout-test.sh`
- `test/shell.d/keybindings-menu-test.sh`
- `test/shell.d/kitty-config-test.sh`
- `test/shell.d/launch-browser-test.sh`
- `test/shell.d/legacy-power-udev-rules-migration-test.sh`
- `test/shell.d/locate-test.sh`
- `test/shell.d/menu-images-test.sh`
- `test/shell.d/mise-work-path-test.sh`
- `test/shell.d/monitor-modeless-test.sh`
- `test/shell.d/neovim-remote-yanks-test.sh`
- `test/shell.d/nopasswd-sudo-expiry-test.sh`
- `test/shell.d/openclaw-cli-test.sh`
- `test/shell.d/openclaw-onboard-test.sh`
- `test/shell.d/passwordless-grant-lifecycle-test.sh`
- `test/shell.d/plymouth-set-test.sh`
- `test/shell.d/powerprofiles-set-test.sh`
- `test/shell.d/provision-user-test.sh`
- `test/shell.d/retired-installer-artifacts-migration-test.sh`
- `test/shell.d/screensaver-workspace-test.sh`
- `test/shell.d/security-entrypoint-symlink-test.sh`
- `test/shell.d/security-fingerprint-remove-test.sh`
- `test/shell.d/shell-ipc-socket-test.sh`
- `test/shell.d/shell-shortcuts-test.sh`
- `test/shell.d/snapper-test.sh`
- `test/shell.d/snapper-timeline-leak-test.sh`
- `test/shell.d/sshd-hardening-migration-test.sh`
- `test/shell.d/system-sleep-ownership-migration-test.sh`
- `test/shell.d/terminal-cwd-test.sh`
- `test/shell.d/theme-staging-test.sh`
- `test/shell.d/theme-templates-test.sh`
- `test/shell.d/toggle-input-device-test.sh`
- `test/shell.d/unowned-system-paths-test.sh`
- `test/shell.d/update-disk-space-test.sh`
- `test/shell.d/update-hook-security-test.sh`
- `test/shell.d/update-lock-test.sh`
- `test/shell.d/update-sequence-test.sh`
- `test/shell.d/update-stay-awake-security-test.sh`
- `test/shell.d/update-user-path-test.sh`
- `test/shell.d/webapp-install-escaping-test.sh`
- `test/shell.d/windows-vm-mount-boundary-test.sh`

</details>

