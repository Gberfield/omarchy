# LocalSend sharing validation

The Share menu and CLI now support native LocalSend text messages through a multiline composer or `omarchy share text [message]`. Clipboard sharing uses LocalSend's native `--text` route without temporary files, aligned with guilhermetk's independently authored #6979. His contribution is credited in the reconciliation commit; his branch is unchanged.

Text and clipboard launches share the existing protected launcher: fixed systemd descriptions keep message contents out of command-derived journal descriptions, environment expansion is disabled, flag-like messages are protected, and the detached service reports LocalSend errors. Clipboard-read failures and file/folder service-launch failures also notify. File/folder selection remains unchanged. LocalSend still receives text in process arguments and trims surrounding whitespace.

The contribution branch now includes quattro at `4e059acff2f4e4c4e5a303ce9bc97223097e45eb`, without rewriting history. English menu and notification catalog entries follow the current translation system. The composer pins GTK/GDK 3 and uses the system Python.

Validation on October 17, 2026:
- Final sharing suite: **21 tests passed without skips**, plus the real menu-parser assertion. Includes privacy, literal/flag-like text, cancellation, clipboard reads, oversized clipboard errors, scheduling and detached child failures, file/folder routes, and catalog-based notifications.
- New real GTK suite: **four scenarios passed under Xvfb**, covering multiline Unicode output, button sensitivity, Ctrl+Enter, Cancel, Escape, and blank Ctrl+Enter. The rendered composer was inspected with entered text. The suite explicitly skips when GTK or a display is unavailable.
- Full CLI suite passed with GNU awk. ShellCheck and Bash syntax checks passed.
- Current upstream catalog structure, reference, placeholder, plural and number checks passed. `extract-scan --check` reports no candidates and no stale catalogs. The complete i18n shell test later fails in the unchanged locale-generator section because this container runs as root and has no installed `/usr/share/omarchy`; this is not a clean full i18n-suite result.
- Released LocalSend **1.18.2** was launched under Xvfb with a synthetic flag-like Unicode message. Its Send view staged native text with the expected **31-byte** trimmed payload. No message was sent to another device; multicast discovery is restricted here.
- The aggregate `./test/all` runner stalled outside sharing. A complete per-file shell sweep with 120-second limits and per-file output logs compared the original and reconciled pre-upstream-sync trees: **322/323 files exercised; the same 69 files failed; no new failing files and no timeouts**. There were skipped checks in 35/36 files; the additional skip is the real GTK suite in the headless sweep, separately run successfully under Xvfb. This comparison is not a claim that the final current-upstream full suite is green.

Remaining acceptance gaps:
- Real systemd/user-journal checks and the packaged installed-Omarchy desktop/VM acceptance suite need a systemd-backed Omarchy host. This container is not booted with systemd; starting a user manager fails.
- Upstream GitHub Actions currently reports `action_required` before creating any jobs. The available connection cannot approve that workflow run. [Current run](https://github.com/omacom/omarchy/actions/runs/39080657887).

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

