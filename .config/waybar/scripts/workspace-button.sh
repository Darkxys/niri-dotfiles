#!/usr/bin/env bash

id="$1"

python3 - "$id" <<'PY'
import json
import subprocess
import sys

workspace_id = int(sys.argv[1])
try:
    workspaces = json.loads(subprocess.check_output(["niri", "msg", "--json", "workspaces"]))
except Exception:
    raise SystemExit(0)

match = next((ws for ws in workspaces if ws.get("idx") == workspace_id), None)

if match is None:
    raise SystemExit(0)

classes = []
if match.get("is_focused") or match.get("is_active"):
    classes.append("active")
if len(match.get("windows") or []) == 0:
    classes.append("empty")

print(json.dumps({"text": str(workspace_id), "class": " ".join(classes)}))
PY
