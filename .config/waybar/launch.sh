#!/usr/bin/env bash

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
BASE_CONFIG="$CONFIG_DIR/config.jsonc"
RUNTIME_CONFIG="$CONFIG_DIR/config.runtime"

if [ ! -f "$BASE_CONFIG" ]; then
	BASE_CONFIG="$CONFIG_DIR/config"
fi

width=$(niri msg --json outputs 2>/dev/null | python3 -c "
import json
import sys

def logical_width(output):
    logical = output.get('logical') or output.get('logical_size') or {}
    if isinstance(logical, dict):
        width = logical.get('width') or logical.get('w')
        if isinstance(width, (int, float)):
            return int(width)

    mode = output.get('current_mode') or output.get('mode') or {}
    if isinstance(mode, dict):
        width = mode.get('width')
        scale = output.get('scale')
        if isinstance(width, (int, float)):
            if isinstance(scale, (int, float)) and scale:
                return int(width / scale)
            return int(width)

    width = output.get('width')
    if isinstance(width, (int, float)):
        return int(width)

    return None

try:
    outputs = json.load(sys.stdin)
except Exception:
    outputs = []

focused = next(
    (
        output for output in outputs
        if output.get('is_focused') or output.get('focused') or output.get('focus')
    ),
    outputs[0] if outputs else None,
)

print(logical_width(focused) if focused else 1440)
")

if ! [[ "$width" =~ ^[0-9]+$ ]] || [ "$width" -eq 0 ]; then
	width=1440
fi

margin=$(( width * 125 / 1000 ))
min_bar_width=1080
max_margin=$(( (width - min_bar_width) / 2 ))

if [ "$max_margin" -lt 0 ]; then
	max_margin=0
fi

if [ "$margin" -gt "$max_margin" ]; then
	margin=$max_margin
fi
python3 - "$BASE_CONFIG" "$RUNTIME_CONFIG" "$margin" <<'PY'
import json
import sys


def strip_jsonc_comments(text: str) -> str:
    result = []
    in_string = False
    escaped = False
    in_line_comment = False
    in_block_comment = False
    i = 0

    while i < len(text):
        ch = text[i]
        nxt = text[i + 1] if i + 1 < len(text) else ""

        if in_line_comment:
            if ch == "\n":
                in_line_comment = False
                result.append(ch)
            i += 1
            continue

        if in_block_comment:
            if ch == "*" and nxt == "/":
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue

        if in_string:
            result.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue

        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue

        if ch == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue

        result.append(ch)
        if ch == '"':
            in_string = True
        i += 1

    return "".join(result)

base_path, runtime_path, margin = sys.argv[1:4]
margin = int(margin)

with open(base_path, encoding="utf-8") as f:
    config = json.loads(strip_jsonc_comments(f.read()))

config["margin-top"] = 8
config["margin-left"] = margin
config["margin-right"] = margin

with open(runtime_path, "w", encoding="utf-8") as f:
    json.dump(config, f, indent="\t")
    f.write("\n")
PY

exec waybar -c "$RUNTIME_CONFIG" "$@"
