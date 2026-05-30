#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
packages_file="${repo_dir}/packages.txt"
aur_packages_file="${repo_dir}/packages.aur.txt"

mapfile -t packages < <(grep -Ev '^\s*(#|$)' "$packages_file")
if [ -f "$aur_packages_file" ]; then
	mapfile -t aur_packages < <(grep -Ev '^\s*(#|$)' "$aur_packages_file")
else
	aur_packages=()
fi

if ((${#packages[@]} == 0)); then
	printf 'No packages found in %s\n' "$packages_file"
elif command -v pacman >/dev/null 2>&1; then
	sudo pacman -S --needed "${packages[@]}"
elif command -v yay >/dev/null 2>&1; then
	yay -S --needed "${packages[@]}"
elif command -v paru >/dev/null 2>&1; then
	paru -S --needed "${packages[@]}"
else
	printf 'No supported Arch package manager found. Install packages from %s manually.\n' "$packages_file" >&2
	exit 1
fi

if ((${#aur_packages[@]} == 0)); then
	exit 0
fi

if command -v yay >/dev/null 2>&1; then
	yay -S --needed "${aur_packages[@]}"
elif command -v paru >/dev/null 2>&1; then
	paru -S --needed "${aur_packages[@]}"
else
	printf 'Skipping optional AUR packages from %s: yay/paru not found.\n' "$aur_packages_file" >&2
fi
