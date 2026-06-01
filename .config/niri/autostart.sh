#!/bin/sh

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
local_env="$config_home/environment.d/rice-local.conf"

command_exists() {
	command -v "$1" >/dev/null 2>&1
}

if [ -r "$local_env" ]; then
	set -a
	. "$local_env"
	set +a
fi

# Cursor theme for niri / Wayland / Xwayland apps.
export XCURSOR_THEME="${XCURSOR_THEME:-Bibata-Modern-Classic}"
export XCURSOR_SIZE="${XCURSOR_SIZE:-24}"
export XCURSOR_PATH="${XCURSOR_PATH:-$config_home/niri:$HOME/.icons:$HOME/.local/share/icons:/usr/share/icons}"

# Keep DBus/systemd-activated services, including xdg-desktop-portal, on the
# same Wayland session/theme context as apps launched by niri.
if command_exists dbus-update-activation-environment; then
	dbus-update-activation-environment --systemd \
		DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION \
		XCURSOR_THEME XCURSOR_SIZE XCURSOR_PATH
fi

wallpaper="${NIRI_WALLPAPER:-$HOME/Pictures/wallpapers/bg.jpg}"
if command_exists swaybg && [ -f "$wallpaper" ]; then
	swaybg -i "$wallpaper" -m fill &
fi

command_exists mako && mako &
command_exists wl-paste && command_exists cliphist && wl-paste --watch cliphist store &
[ -x "$config_home/waybar/launch.sh" ] && "$config_home/waybar/launch.sh" &

if command_exists wlsunset && [ -n "${WLSUNSET_LAT:-}" ] && [ -n "${WLSUNSET_LON:-}" ]; then
	wlsunset -l "$WLSUNSET_LAT" -L "$WLSUNSET_LON" -t "${WLSUNSET_TEMP_NIGHT:-2500}" -T "${WLSUNSET_TEMP_DAY:-6200}" &
fi

for agent in \
	/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 \
	/usr/libexec/polkit-gnome-authentication-agent-1 \
	/usr/lib/polkit-kde-authentication-agent-1; do
	if [ -x "$agent" ]; then
		"$agent" &
		break
	fi
done
