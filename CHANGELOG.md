# Changelog

## 0.1.0

- Forked the original Claude Status Bar architecture for Codex.
- Added documented Codex lifecycle hook support for CLI and Desktop.
- Added explicit first-launch confirmation before hook installation.
- Added safe, idempotent `~/.codex/hooks.json` merging and backup.
- Replaced Node hook scripts with a universal native Swift helper.
- Replaced Claude artwork with the locally installed full-color Codex pet-style app mark and subtle motion.
- Added bounded `turn_aborted` event detection so Esc clears working state.
- Removed message parsing, upstream release checks, and external runtime dependencies.
