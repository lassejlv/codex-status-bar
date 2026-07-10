#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
swiftc Sources/HookCore.swift Tests/HookCoreTests.swift -o build/tests/HookCoreTests
build/tests/HookCoreTests
scripts/test-hook-helper.sh
