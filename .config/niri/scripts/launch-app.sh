#!/bin/sh
set -eu

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
apps_env="$config_home/niri/apps.env"

if [ -f "$apps_env" ]; then
	# shellcheck disable=SC1090
	. "$apps_env"
fi

run_command_string() {
	if [ -n "${1:-}" ]; then
		exec sh -c "exec $1"
	fi
}

case "${1:-}" in
	editor)
		run_command_string "${NIRI_APP_EDITOR:-}"
		if command -v code >/dev/null 2>&1; then
			exec code --enable-features=UseOzonePlatform --ozone-platform=wayland --disable-gpu
		fi
		if command -v codium >/dev/null 2>&1; then
			exec codium --enable-features=UseOzonePlatform --ozone-platform=wayland
		fi
		exec alacritty
		;;
	browser)
		run_command_string "${NIRI_APP_BROWSER:-}"
		exec xdg-open about:blank
		;;
	notes)
		run_command_string "${NIRI_APP_NOTES:-}"
		if command -v obsidian >/dev/null 2>&1; then
			exec obsidian
		fi
		exec fuzzel
		;;
	*)
		printf 'Usage: %s {editor|browser|notes}\n' "$0" >&2
		exit 2
		;;
esac
