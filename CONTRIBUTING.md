# Contributing

Keep Codex Status Bar small, local, native, and dependency-free.

Welcome changes include correctness fixes, Codex hook compatibility, performance improvements, terminal/app surface detection, accessibility, and restrained visual polish.

Out of scope: transcript parsing, usage or cost dashboards, telemetry, API calls, background system behavior, and unrelated agent providers.

Before submitting a change, run:

```bash
scripts/test.sh
swiftc -typecheck Sources/*.swift -framework Cocoa
bash -n build.sh
./build.sh
```

Test behavioral changes in both Codex CLI and Codex Desktop when possible. Use Conventional Commit prefixes such as `feat`, `fix`, `test`, `docs`, and `chore`.
