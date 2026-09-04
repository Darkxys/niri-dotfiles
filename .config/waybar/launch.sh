#!/usr/bin/env bash

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
BASE_CONFIG="$CONFIG_DIR/config.jsonc"
RUNTIME_CONFIG="$CONFIG_DIR/config.runtime"

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

command_exists python3 || exit 0
command_exists waybar || exit 0

if [ ! -f "$BASE_CONFIG" ]; then
	BASE_CONFIG="$CONFIG_DIR/config"
fi

python3 - "$BASE_CONFIG" "$RUNTIME_CONFIG" <<'PY'
import copy
import json
import shutil
import subprocess
import sys

DEFAULT_WIDTH = 1440
MIN_BAR_WIDTH = 1750
MARGIN_PER_MILLE = 125


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


def niri_outputs() -> list[tuple[str | None, dict]]:
    if shutil.which("niri") is None:
        return []

    try:
        result = subprocess.run(
            ["niri", "msg", "--json", "outputs"],
            check=True,
            capture_output=True,
            text=True,
        )
        outputs = json.loads(result.stdout)
    except Exception:
        return []

    if isinstance(outputs, dict):
        return [
            (name, output)
            for name, output in outputs.items()
            if isinstance(output, dict)
        ]

    if isinstance(outputs, list):
        return [
            (output.get("name"), output)
            for output in outputs
            if isinstance(output, dict)
        ]

    return []


def output_width(output: dict) -> int | None:
    logical = output.get("logical") or output.get("logical_size") or {}
    if isinstance(logical, dict):
        width = logical.get("width") or logical.get("w")
        if isinstance(width, (int, float)):
            return int(width)

    mode = output.get("current_mode") or output.get("mode") or {}
    modes = output.get("modes")
    if isinstance(mode, int) and isinstance(modes, list) and 0 <= mode < len(modes):
        mode = modes[mode]

    if isinstance(mode, dict):
        width = mode.get("width")
        scale = output.get("scale")
        if isinstance(width, (int, float)):
            if isinstance(scale, (int, float)) and scale:
                return int(width / scale)
            return int(width)

    width = output.get("width")
    if isinstance(width, (int, float)):
        return int(width)

    return None


def margin_for_width(width: int | None) -> int:
    if not isinstance(width, int) or width <= 0:
        width = DEFAULT_WIDTH

    margin = width * MARGIN_PER_MILLE // 1000
    max_margin = (width - MIN_BAR_WIDTH) // 2
    if max_margin < 0:
        max_margin = 0

    return min(margin, max_margin)


def config_for_output(base_config: dict, name: str | None, output: dict) -> dict:
    config = copy.deepcopy(base_config)
    margin = margin_for_width(output_width(output))

    config["margin-top"] = 8
    config["margin-left"] = margin
    config["margin-right"] = margin

    if name:
        config["output"] = name

    return config


base_path, runtime_path = sys.argv[1:3]

with open(base_path, encoding="utf-8") as f:
    base_config = json.loads(strip_jsonc_comments(f.read()))

outputs = niri_outputs()
if outputs:
    runtime_config = [
        config_for_output(base_config, name, output)
        for name, output in outputs
    ]
else:
    runtime_config = config_for_output(base_config, None, {})

with open(runtime_path, "w", encoding="utf-8") as f:
    json.dump(runtime_config, f, indent="\t")
    f.write("\n")
PY

exec waybar -c "$RUNTIME_CONFIG" "$@"
