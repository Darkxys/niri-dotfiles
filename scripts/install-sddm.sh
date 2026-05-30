#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
backup_root="${BACKUP_ROOT:-/etc/sddm.pre-stow/$(date +%Y%m%d-%H%M%S)}"
silent_repo="${SILENT_SDDM_REPO:-https://github.com/uiriansan/SilentSDDM.git}"
silent_ref="${SILENT_SDDM_REF:-main}"
silent_config="${SILENT_SDDM_CONFIG:-rei}"
silent_config="${silent_config#configs/}"
silent_config="${silent_config%.conf}"
silent_config_file="configs/${silent_config}.conf"
theme_dir="/usr/share/sddm/themes/silent"
work_dir="$(mktemp -d)"

cleanup() {
	rm -rf "$work_dir"
}
trap cleanup EXIT

is_repo_link() {
	local path="$1"
	local resolved

	[ -L "$path" ] || return 1
	resolved="$(readlink -m "$path" 2>/dev/null || true)"
	[[ "$resolved" == "$repo_dir"/* ]]
}

backup_existing() {
	local path="$1"
	local dest="$backup_root$path"

	if [ ! -e "$path" ] && [ ! -L "$path" ]; then
		return
	fi

	if is_repo_link "$path"; then
		return
	fi

	sudo mkdir -p "$(dirname "$dest")"
	sudo mv "$path" "$dest"
	printf 'Moved %s to %s\n' "$path" "$dest"
}

prepare_theme_dir() {
	if [ -L "$theme_dir" ]; then
		if is_repo_link "$theme_dir"; then
			sudo rm "$theme_dir"
			printf 'Removed stale repo symlink %s\n' "$theme_dir"
		else
			backup_existing "$theme_dir"
		fi
	elif [ -e "$theme_dir" ] && [ ! -d "$theme_dir" ]; then
		backup_existing "$theme_dir"
	elif [ -d "$theme_dir" ]; then
		sudo mkdir -p "$backup_root/usr/share/sddm/themes"
		sudo cp -a "$theme_dir" "$backup_root/usr/share/sddm/themes/silent"
		printf 'Backed up %s to %s\n' "$theme_dir" "$backup_root/usr/share/sddm/themes/silent"
	fi

	sudo mkdir -p "$theme_dir"
}

for cmd in git rsync stow; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$cmd" >&2
		exit 1
	fi
done

backup_existing /etc/sddm.conf.d/10-theme.conf
backup_existing /etc/sddm.conf.d/20-virtual-keyboard.conf

printf 'Fetching SilentSDDM from %s (%s)\n' "$silent_repo" "$silent_ref"
git clone --depth=1 --branch "$silent_ref" "$silent_repo" "$work_dir/SilentSDDM"

prepare_theme_dir
sudo rsync -a --delete \
	--exclude '.git' \
	--exclude 'flake.lock' \
	--exclude 'flake.nix' \
	--exclude 'default.nix' \
	--exclude 'nix' \
	"$work_dir/SilentSDDM/" "$theme_dir/"

if [ ! -f "$theme_dir/$silent_config_file" ]; then
	printf 'SilentSDDM config not found: %s\n' "$silent_config_file" >&2
	printf 'Available configs:\n' >&2
	find "$theme_dir/configs" -maxdepth 1 -type f -name '*.conf' -printf '  %f\n' | sort >&2
	exit 1
fi

if sudo grep -q '^ConfigFile=' "$theme_dir/metadata.desktop"; then
	sudo sed -i "s|^ConfigFile=.*|ConfigFile=$silent_config_file|" "$theme_dir/metadata.desktop"
else
	printf '\nConfigFile=%s\n' "$silent_config_file" | sudo tee -a "$theme_dir/metadata.desktop" >/dev/null
fi
printf 'Selected SilentSDDM config: %s\n' "$silent_config_file"

if [ -d "$theme_dir/fonts" ]; then
	sudo mkdir -p /usr/share/fonts
	sudo rsync -a "$theme_dir/fonts/" /usr/share/fonts/
fi

sudo stow --dir "$repo_dir" --target / --verbose --restow sddm

cat <<'EOF'

SDDM files installed.

Previous system files, if any, were backed up under:
  /etc/sddm.pre-stow/

Recommended test:
  cd /usr/share/sddm/themes/silent
  ./test.sh

If SDDM is not enabled yet:
  sudo systemctl enable sddm.service

To test the theme safely, log out or reboot when ready.
EOF
