#!/usr/bin/env bash
# Bakes the generated scrapyard into map/ and rebuilds JunkyardSimulator.rbxlx,
# so the place opens in Studio with the map already in Workspace.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cargo build --release --quiet --manifest-path "$ROOT/tests/runner/Cargo.toml" --target-dir "$ROOT/tests/runner/target"
FILES="$(cd "$ROOT/src" && find . -name '*.luau' | sed 's|^\./||' | sort)"
OUT="$("$ROOT/tests/runner/target/release/luaurun" "$ROOT/tests/bake.luau" "$ROOT" "$FILES")"

rm -rf "$ROOT/map"
mkdir -p "$ROOT/map/Lighting"
# Split the "@@FILE path" sections into files.
printf '%s\n' "$OUT" | awk -v root="$ROOT" '
	/^@@FILE / { file = root "/" substr($0, 8); next }
	/^@@END/ { file = ""; next }
	file != "" { print > file }
'

# Copy the baked Lighting properties into the project file.
python3 - "$ROOT" <<'EOF'
import json, sys
root = sys.argv[1]
project_path = f"{root}/default.project.json"
project = json.load(open(project_path))
props = json.load(open(f"{root}/map/lighting.props.json"))
props["Technology"] = "ShadowMap"
project["tree"]["Lighting"] = {"$path": "map/Lighting", "$properties": props}
project["tree"]["Workspace"] = {"$properties": {"StreamingEnabled": True}, "Junkyard": {"$path": "map/Junkyard.model.json"}}
with open(project_path, "w") as f:
    json.dump(project, f, indent=2)
    f.write("\n")
EOF
rm "$ROOT/map/lighting.props.json"

rojo build "$ROOT/default.project.json" -o "$ROOT/JunkyardSimulator.rbxl"
