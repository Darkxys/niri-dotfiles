#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${TARGET:-$HOME}"
backup_root="${BACKUP_ROOT:-$HOME/.config.pre-stow/$(date +%Y%m%d-%H%M%S)}"
dry_run=0
skip_packages="${SKIP_PACKAGES:-0}"

config_targets=(
	".config/niri"
	".config/waybar"
	".config/alacritty"
	".config/fish"
	".config/fuzzel"
	".config/mako"
	".config/swaylock"
	".config/wlogout"
	".config/swappy"
	".config/fastfetch"
	".config/btop"
	".config/cava"
	".config/mpv"
	".config/yazi"
	".config/lazygit"
	".config/tmux"
	".config/gtk-3.0"
	".config/gtk-4.0"
	".config/environment.d"
	".config/fcitx5"
	".config/prompt"
	"Pictures/wallpapers"
)

usage() {
	cat <<'EOF'
Usage: ./install.sh [--dry-run] [--skip-packages]

Environment:
  TARGET=/path          Stow target, default: $HOME
  SKIP_PACKAGES=1       Do not install packages
  BACKUP_ROOT=/path     Existing configs backup location
EOF
}

log() {
	printf '==> %s\n' "$*"
}

need_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Missing required command: %s\n' "$1" >&2
		exit 1
	fi
}

is_repo_link() {
	local path="$1"
	local resolved

	[ -L "$path" ] || return 1
	resolved="$(readlink -f "$path" 2>/dev/null || true)"
	[[ "$resolved" == "$repo_dir"/* ]]
}

backup_existing() {
	local rel="$1"
	local path="$target/$rel"
	local dest="$backup_root/$rel"

	if [ ! -e "$path" ] && [ ! -L "$path" ]; then
		return
	fi

	if is_repo_link "$path"; then
		return
	fi

	if ((dry_run)); then
		log "Would move $path to $dest"
		return
	fi

	mkdir -p "$(dirname "$dest")"
	mv "$path" "$dest"
	log "Moved $path to $dest"
}

install_packages() {
	if [[ "$skip_packages" == "1" ]]; then
		log "Skipping package install"
		return
	fi

	log "Installing packages from packages.txt"
	if ((dry_run)); then
		log "Would run scripts/install-packages.sh"
		return
	fi

	"$repo_dir/scripts/install-packages.sh"
}

make_executable() {
	if ((dry_run)); then
		log "Would chmod helper scripts"
		return
	fi

	find "$repo_dir/.config/niri" "$repo_dir/.config/waybar" "$repo_dir/.config/tmux" \
		-type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +
	chmod +x "$repo_dir/install.sh" "$repo_dir/scripts/install-packages.sh" "$repo_dir/scripts/restow.sh"
}

stow_packages() {
	need_cmd stow

	log "Preparing target directories"
	if ((dry_run)); then
		log "Would create $target/.config and $target/Pictures"
	else
		mkdir -p "$target/.config" "$target/Pictures"
	fi

	log "Backing up existing config targets"
	for rel in "${config_targets[@]}"; do
		backup_existing "$rel"
	done

	log "Stowing config and wallpapers into $target"
	if ((dry_run)); then
		stow --dir "$repo_dir" --target "$target" --simulate --verbose --restow . wallpapers
	else
		stow --dir "$repo_dir" --target "$target" --verbose --restow . wallpapers
	fi
}

while (($#)); do
	case "$1" in
		--dry-run)
			dry_run=1
			skip_packages=1
			;;
		--skip-packages)
			skip_packages=1
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			printf 'Unknown option: %s\n' "$1" >&2
			usage >&2
			exit 1
			;;
	esac
	shift
done

install_packages
make_executable
stow_packages

log "Done"
cat <<EOF

Next steps:
  1. Review $backup_root if anything was backed up.
  2. Edit ~/.config/niri/outputs.kdl for your monitor layout.
  3. Set WLSUNSET_LAT and WLSUNSET_LON if you want wlsunset enabled.
EOF
