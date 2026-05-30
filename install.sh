#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="${TARGET:-$HOME}"
backup_root="${BACKUP_ROOT:-$HOME/.config.pre-stow/$(date +%Y%m%d-%H%M%S)}"
dry_run=0
skip_packages="${SKIP_PACKAGES:-0}"
skip_gtk_theme="${SKIP_GTK_THEME:-0}"
gtk_theme_repo="${GTK_THEME_REPO:-https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme.git}"
gtk_theme_ref="${GTK_THEME_REF:-master}"
gtk_theme_name="${GTK_THEME_NAME:-Tokyonight-BL-LB}"
gtk_theme_full_name="${GTK_THEME_FULL_NAME:-${gtk_theme_name}-Dark-Storm}"
gtk_theme_work_dir=""

cleanup() {
	if [ -n "$gtk_theme_work_dir" ]; then
		rm -rf "$gtk_theme_work_dir"
	fi
}
trap cleanup EXIT

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
	".config/gtk-3.0"
	".config/gtk-4.0"
	".config/environment.d"
	".config/xdg-desktop-portal"
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
  SKIP_GTK_THEME=1      Do not fetch/install the GTK theme
  BACKUP_ROOT=/path     Existing configs backup location
  GTK_THEME_REPO=url    Tokyonight GTK source repo
  GTK_THEME_REF=ref     Tokyonight GTK git ref, default: master
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

	find "$repo_dir/.config/niri" "$repo_dir/.config/waybar" \
		-type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} +
	chmod +x "$repo_dir/install.sh" "$repo_dir/scripts/install-packages.sh" "$repo_dir/scripts/restow.sh"
}

stow_packages() {
	need_cmd stow

	log "Preparing target directories"
	if ((dry_run)); then
		log "Would create $target/.config, $target/.themes, and $target/Pictures"
	else
		mkdir -p "$target/.config" "$target/.themes" "$target/Pictures"
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

install_gtk_theme() {
	if [[ "$skip_gtk_theme" == "1" ]]; then
		log "Skipping GTK theme install"
		return
	fi

	need_cmd git
	local theme_dest="$target/.themes"
	local source_dir

	log "Installing GTK theme $gtk_theme_full_name"
	if ((dry_run)); then
		log "Would clone $gtk_theme_repo ($gtk_theme_ref) and install to $theme_dest"
		return
	fi

	mkdir -p "$theme_dest"
	gtk_theme_work_dir="$(mktemp -d)"
	git clone --depth=1 --branch "$gtk_theme_ref" "$gtk_theme_repo" "$gtk_theme_work_dir/Tokyonight-GTK-Theme"
	source_dir="$gtk_theme_work_dir/Tokyonight-GTK-Theme/themes"

	(
		cd "$source_dir"
		bash ./install.sh -d "$theme_dest" -n "$gtk_theme_name" -c dark --tweaks storm
	)

	if [ ! -d "$theme_dest/$gtk_theme_full_name" ]; then
		printf 'Expected GTK theme was not installed: %s\n' "$theme_dest/$gtk_theme_full_name" >&2
		exit 1
	fi
}

apply_desktop_settings() {
	log "Applying GTK, icon, cursor, and portal settings"
	if ((dry_run)); then
		log "Would set gsettings for $gtk_theme_full_name"
		return
	fi

	if command -v gsettings >/dev/null 2>&1; then
		gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme_full_name"
		gsettings set org.gnome.desktop.interface color-scheme prefer-dark
		gsettings set org.gnome.desktop.interface icon-theme Adwaita
		gsettings set org.gnome.desktop.interface cursor-theme Bibata-Modern-Classic
		gsettings set org.gnome.desktop.interface cursor-size 24
	else
		log "Skipping gsettings: command not found"
	fi

	if command -v dbus-update-activation-environment >/dev/null 2>&1; then
		dbus-update-activation-environment --systemd \
			DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION \
			XCURSOR_THEME XCURSOR_SIZE XCURSOR_PATH || true
	fi

	if command -v systemctl >/dev/null 2>&1; then
		systemctl --user restart \
			xdg-desktop-portal.service \
			xdg-desktop-portal-gtk.service \
			xdg-desktop-portal-gnome.service >/dev/null 2>&1 || true
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
install_gtk_theme
apply_desktop_settings

log "Done"
cat <<EOF

Next steps:
  1. Review $backup_root if anything was backed up.
  2. Edit ~/.config/niri/outputs.kdl for your monitor layout.
  3. Set WLSUNSET_LAT and WLSUNSET_LON if you want wlsunset enabled.
  4. Log out and back in if GTK dialogs were open during install.
EOF
