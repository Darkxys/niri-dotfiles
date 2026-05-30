# Dotfiles

Personal Niri desktop rice managed with GNU Stow.

This repo is the source of truth for my config. After install, files in
`~/.config` and `~/Pictures/wallpapers` are symlinks back into this repo, so
editing either path updates the same files.

## Includes

- Niri, Waybar, Alacritty, Fish, Fuzzel, Mako, Swaylock, Wlogout, Swappy
- SDDM `silent` login theme
- Fastfetch, Btop, Cava, MPV, Yazi, Lazygit
- GTK 3/4, Fcitx5, Starship prompt, MIME defaults
- Wallpapers: `bg.jpg`, `purple-horizon.jpg`

## Layout

```text
.
├── .config/      # stowed to ~/.config
├── sddm/         # optional system package, stowed to /
├── wallpapers/   # stowed to ~/Pictures/wallpapers
├── scripts/      # helper scripts
├── install.sh
├── packages.txt
├── packages.aur.txt
└── local.env.example
```

## Install

Preview first:

```bash
cd ~/dotfiles
./install.sh --dry-run
```

Install:

```bash
./install.sh
```

Skip packages:

```bash
./install.sh --skip-packages
```

Package installation reads `packages.txt` and prefers `pacman`, then `yay`,
then `paru`. Optional AUR packages live in `packages.aur.txt` and are installed
with `yay` or `paru` when available.

The installer also fetches `Fausto-Korpsvart/Tokyonight-GTK-Theme`, installs the
`Tokyonight-BL-LB-Dark-Storm` GTK theme to `~/.themes`, and applies the matching
GTK settings for themed dialogs. Set `SKIP_GTK_THEME=1` to skip that step.

## Keybindings

The main Niri keybindings live in:

```text
~/.config/niri/keybinds.kdl
```

`Mod` means `Super` in a normal Niri session. Show the shortcut overlay with
`Mod+Shift+/`.

Common binds:

| Key | Action |
| --- | --- |
| `Mod+Return` | Open Alacritty |
| `Mod+Space` | Open Fuzzel |
| `Super+Alt+L` | Lock screen |
| `Mod+T` | Open Wlogout |
| `Mod+C` | Open editor |
| `Mod+B` | Open browser |
| `Mod+N` | Open notes |
| `Mod+E` | Open Yazi |
| `Mod+S` | Open SSH picker |
| `Mod+Q` | Close focused window |
| `Mod+O` | Toggle overview |
| `Mod+H/J/K/L` | Move focus |
| `Mod+Ctrl+H/J/K/L` | Move window/column |
| `Mod+1`-`Mod+9` | Focus workspace |
| `Mod+Ctrl+1`-`Mod+Ctrl+9` | Move column to workspace |
| `Mod+R` | Cycle column widths |
| `Mod+F` | Maximize column |
| `Mod+Shift+F` | Toggle fullscreen |
| `Mod+V` | Toggle floating |
| `Print` | Area screenshot |
| `Ctrl+Print` | Screen screenshot |
| `Alt+Print` | Window screenshot |
| `Mod+Shift+E` | Quit Niri |

Editor, browser, and notes are local-friendly. Override them without dirtying
the repo:

```bash
cp ~/.config/niri/apps.env.example ~/.config/niri/apps.env
```

Then edit `~/.config/niri/apps.env`:

```sh
NIRI_APP_EDITOR='codium'
NIRI_APP_BROWSER='firefox'
NIRI_APP_NOTES='obsidian'
```

## SDDM

The SDDM login screen is installed separately because it writes to `/etc` and
`/usr/share`. The installer fetches `uiriansan/SilentSDDM` from upstream, copies
it to `/usr/share/sddm/themes/silent`, selects the `rei` SilentSDDM variant,
and stows this repo's small SDDM config:

```bash
./scripts/install-sddm.sh
```

Use another SilentSDDM variant by setting `SILENT_SDDM_CONFIG`:

```bash
SILENT_SDDM_CONFIG=default ./scripts/install-sddm.sh
```

It configures:

```text
/etc/sddm.conf.d/10-theme.conf
/usr/share/sddm/themes/silent/
```

The SDDM theme name stays `silent`; the selected SilentSDDM style is `rei`.

## Local Setup

Niri outputs are intentionally generic. Configure your real monitors in:

```text
~/.config/niri/outputs.kdl
```

Discover output names with:

```bash
niri msg outputs
```

The original desktop layout is kept as an example:

```text
~/.config/niri/outputs.desktop.example.kdl
```

Optional local environment values can be based on `local.env.example`:

```ini
NIRI_WALLPAPER=/home/you/Pictures/wallpapers/bg.jpg
WLSUNSET_LAT=
WLSUNSET_LON=
```

Put session-wide values in `~/.config/environment.d/rice-local.conf`, then log
out and back in.
