# Troubleshooting

## Nothing changes while Codex works

Open `/hooks` in Codex. Review and trust the Codex Status Bar commands; Codex skips untrusted hooks by design.

Also check that hooks are enabled in `~/.codex/config.toml` and that `~/.codex/hooks.json` contains commands marked `codex-status-bar-hook`.

## The helper path is wrong

Moving the app after hook installation leaves the old absolute path in the hook commands. Open the status menu and choose **Reinstall Hooks…**.

## The app disappears

Codex Status Bar launches on `SessionStart` and quits after Codex is no longer active. Launch it manually to install or repair hooks.

## Desktop rows remain longer than expected

Codex does not currently expose a documented `SessionEnd` hook. Desktop sessions share a long-lived process, so idle rows expire using the app's hide-idle interval.

## Debug state

Per-session status lives in `~/.codex/statusbar/state.d`. These files contain metadata only and can be removed safely while Codex is idle.
