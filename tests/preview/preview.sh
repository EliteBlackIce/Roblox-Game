#!/usr/bin/env bash
# Renders art to a PNG so models can be reviewed without opening Studio.
# usage: tests/preview/preview.sh <target> <out.png> [filter] [render.py args...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="$1"; OUT="$2"; shift 2
FILTER=""
if [ $# -gt 0 ] && [[ "$1" != --* ]]; then FILTER="$1"; shift; fi
cargo build --release --quiet --manifest-path "$ROOT/tests/runner/Cargo.toml" --target-dir "$ROOT/tests/runner/target"
FILES="$(cd "$ROOT/src" && find . -name '*.luau' | sed 's|^\./||' | sort)"
TMP="$(mktemp)"
"$ROOT/tests/runner/target/release/luaurun" "$ROOT/tests/preview/dump.luau" "$ROOT" "$FILES" "$TARGET" $FILTER > "$TMP"
python3 "$ROOT/tests/preview/render.py" "$TMP" "$OUT" "$@"
rm -f "$TMP"
