#!/usr/bin/env bash
# Builds a tiny Luau runner (mlua) and runs the headless playtest.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cargo build --release --quiet --manifest-path "$ROOT/tests/runner/Cargo.toml" --target-dir "$ROOT/tests/runner/target"
FILES="$(cd "$ROOT/src" && find . -name '*.luau' | sed 's|^\./||' | sort)"
"$ROOT/tests/runner/target/release/luaurun" "$ROOT/tests/playtest.luau" "$ROOT" "$FILES"
