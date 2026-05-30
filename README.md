# Dotfiles

Personal Niri desktop rice managed with GNU Stow.

This repo is the source of truth for my config. After install, files in
`~/.config` and `~/Pictures/wallpapers` are symlinks back into this repo, so
editing either path updates the same files.

## Includes

- Niri, Waybar, Alacritty, Fish, Fuzzel, Mako, Swaylock, Wlogout, Swappy
- SDDM `silent` login theme
- Fastfetch, Btop, Cava, MPV, Yazi, Lazygit, Tmux
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

## Day To Day

Check whether a live config points into the repo:

```bash
readlink -f ~/.config/fish/config.fish
```

Save changes:

```bash
cd ~/dotfiles
git status
git add .
git commit -m "Update config"
git push
```

Re-apply links after moving files around:

```bash
./scripts/restow.sh
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

App keybinds for editor, browser, and notes go through:

```text
~/.config/niri/scripts/launch-app.sh
```

To override them without dirtying the repo, copy:

```bash
cp ~/.config/niri/apps.env.example ~/.config/niri/apps.env
```

Then edit `apps.env`, for example:

```sh
NIRI_APP_EDITOR='codium'
NIRI_APP_BROWSER='firefox'
NIRI_APP_NOTES='obsidian'
```

## Publish

```bash
gh repo create dotfiles --private --source=. --remote=origin --push
```

Audit before making it public: hostnames, secrets, tokens, SSH aliases, and
anything too machine-specific.
