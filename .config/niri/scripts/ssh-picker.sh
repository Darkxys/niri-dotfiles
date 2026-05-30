#!/usr/bin/env bash

set -euo pipefail

ssh_config="${XDG_CONFIG_HOME:-$HOME/.config}"
ssh_config="${ssh_config%/.config}/.ssh/config"

notify() {
    notify-send "SSH picker" "$1"
}

if [[ ! -f "$ssh_config" ]]; then
    notify "No SSH config found at $ssh_config"
    exit 1
fi

mapfile -t hosts < <(
    awk '
    BEGIN { IGNORECASE = 1 }
    /^\s*Host\s+/ {
        for (i = 2; i <= NF; i++) {
            host = $i
            if (host ~ /[*?]/) {
                continue
            }
            seen[host] = 1
        }
    }
    END {
        for (host in seen) {
            print host
        }
    }
    ' "$ssh_config" | sort -f
)

if [[ ${#hosts[@]} -eq 0 ]]; then
    notify "No named SSH hosts found in $ssh_config"
    exit 1
fi

selection="$(
    printf '%s\n' "${hosts[@]}" |
        fuzzel --dmenu \
            --prompt "SSH: " \
            --placeholder "Choose a host" \
            --lines 12 \
            --width 50
)"

if [[ -z "$selection" ]]; then
    exit 0
fi

exec alacritty --class Alacritty,Alacritty -T "SSH: $selection" -e ssh "$selection"
