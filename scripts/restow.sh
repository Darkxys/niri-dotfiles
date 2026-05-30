#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${TARGET:-$HOME}"

mkdir -p "$target/.config" "$target/Pictures"
stow --dir "$repo_dir" --target "$target" --restow . wallpapers
