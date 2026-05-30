#!/usr/bin/env python3

from __future__ import annotations

import pathlib
import re
import signal
import subprocess
import sys

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402


CONFIG_PATH = pathlib.Path.home() / ".config" / "niri" / "keybinds.kdl"
APP_ID = "local.niri.shortcuts.overlay"


class Shortcut:
    def __init__(self, section: str, key: str, title: str) -> None:
        self.section = section
        self.key = key
        self.title = title


SECTION_ALIASES = {
    "Session and system actions": "Window and session actions",
    "Window focus and movement": "Window and session actions",
}


def notify(summary: str, body: str) -> None:
    subprocess.run(["notify-send", summary, body], check=False)


def parse_shortcuts(config_path: pathlib.Path) -> list[Shortcut]:
    if not config_path.exists():
        raise FileNotFoundError(config_path)

    shortcuts: list[Shortcut] = []
    current_section = "Other"
    expect_section = False
    in_bind = False
    bind_key = ""
    bind_lines: list[str] = []

    def flush_bind() -> None:
        nonlocal bind_key, bind_lines
        if not bind_key:
            return

        block = "\n".join(bind_lines)

        title_match = re.search(r'hotkey-overlay-title="([^"]+)"', block)
        if not title_match:
            bind_key = ""
            bind_lines = []
            return

        title = title_match.group(1)

        section_name = SECTION_ALIASES.get(current_section, current_section)
        shortcuts.append(Shortcut(section_name, bind_key, title))
        bind_key = ""
        bind_lines = []

    for raw_line in config_path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()

        if re.fullmatch(r"// -{5,}", stripped):
            expect_section = True
            continue

        if expect_section and stripped.startswith("// "):
            current_section = stripped[3:].strip() or "Other"
            expect_section = False
            continue

        if expect_section:
            expect_section = False

        if stripped.startswith("//"):
            continue

        if not in_bind and stripped and not stripped.startswith(("}", "{")) and "{" in stripped:
            bind_key = stripped.split()[0]
            if bind_key == "binds":
                continue
            bind_lines = [raw_line]
            in_bind = True
            if "}" in stripped:
                flush_bind()
                in_bind = False
            continue

        if in_bind:
            bind_lines.append(raw_line)
            if "}" in stripped:
                flush_bind()
                in_bind = False

    return shortcuts


class ShortcutOverlay(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.connect("activate", self.on_activate)
        self.connect("command-line", self.on_command_line)
        self.window: Gtk.ApplicationWindow | None = None

    def on_command_line(self, app: Gio.Application, command_line: Gio.ApplicationCommandLine) -> int:
        self.activate()
        return 0

    def build_section_card(self, section: str, items: list[Shortcut]) -> Gtk.Box:
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        card.add_css_class("shortcut-card")
        card.set_size_request(360, -1)
        card.set_margin_top(10)
        card.set_margin_bottom(10)
        card.set_margin_start(10)
        card.set_margin_end(10)

        title = Gtk.Label(label=section)
        title.set_xalign(0)
        title.add_css_class("section-title")
        card.append(title)

        for item in items:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
            row.add_css_class("shortcut-row")

            key = Gtk.Label(label=item.key)
            key.set_xalign(0)
            key.set_wrap(False)
            key.set_hexpand(False)
            key.add_css_class("shortcut-key")

            action = Gtk.Label(label=item.title)
            action.set_xalign(0)
            action.set_wrap(True)
            action.set_hexpand(True)
            action.add_css_class("shortcut-action")

            row.append(key)
            row.append(action)
            card.append(row)

        return card

    def build_ui(self, shortcuts: list[Shortcut]) -> Gtk.ApplicationWindow:
        win = Gtk.ApplicationWindow(application=self)
        win.set_title("Shortcuts")
        win.set_default_size(1280, 860)
        win.set_decorated(False)
        win.set_resizable(True)
        win.add_css_class("shortcuts-window")

        key_controller = Gtk.EventControllerKey()
        key_controller.connect("key-pressed", self.on_key_pressed)
        win.add_controller(key_controller)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        outer.set_margin_top(28)
        outer.set_margin_bottom(28)
        outer.set_margin_start(28)
        outer.set_margin_end(28)

        heading = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        title = Gtk.Label(label="Niri Shortcuts")
        title.set_xalign(0)
        title.add_css_class("overlay-title")

        subtitle = Gtk.Label(label="Grouped shortcut reference. Press Esc to close.")
        subtitle.set_xalign(0)
        subtitle.add_css_class("overlay-subtitle")

        heading.append(title)
        heading.append(subtitle)
        outer.append(heading)

        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroller.set_vexpand(True)

        flow = Gtk.FlowBox()
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_max_children_per_line(3)
        flow.set_min_children_per_line(2)
        flow.set_row_spacing(10)
        flow.set_column_spacing(10)
        flow.set_valign(Gtk.Align.START)

        section_map: dict[str, list[Shortcut]] = {}
        for item in shortcuts:
            section_map.setdefault(item.section, []).append(item)

        for section, items in section_map.items():
            flow.insert(self.build_section_card(section, items), -1)

        scroller.set_child(flow)
        outer.append(scroller)
        win.set_child(outer)

        provider = Gtk.CssProvider()
        provider.load_from_data(
            b"""
            window.shortcuts-window {
                background: rgba(18, 20, 24, 0.20);
                color: #f2efe8;
            }

            .overlay-title {
                font-size: 28px;
                font-weight: 700;
                color: #f7f1e3;
            }

            .overlay-subtitle {
                font-size: 14px;
                color: #b7b0a4;
            }

            .shortcut-card {
                background: rgba(36, 39, 46, 0.72);
                border-radius: 16px;
                padding: 18px;
                border: 1px solid rgba(223, 190, 106, 0.18);
            }

            .section-title {
                font-size: 18px;
                font-weight: 700;
                color: #dfbe6a;
                margin-bottom: 6px;
            }

            .shortcut-row {
                padding: 3px 0;
            }

            .shortcut-key {
                font-family: "JetBrainsMono Nerd Font Mono", monospace;
                font-size: 13px;
                min-width: 150px;
                color: #f7f1e3;
            }

            .shortcut-action {
                font-size: 14px;
                color: #d3cdc2;
            }
            """
        )
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        return win

    def on_key_pressed(
        self,
        controller: Gtk.EventControllerKey,
        keyval: int,
        keycode: int,
        state: Gdk.ModifierType,
    ) -> bool:
        if keyval == Gdk.KEY_Escape:
            if self.window is not None:
                self.window.close()
            return True
        return False

    def on_activate(self, app: Gtk.Application) -> None:
        if self.window is not None:
            self.window.present()
            return

        try:
            shortcuts = parse_shortcuts(CONFIG_PATH)
        except FileNotFoundError:
            notify("Shortcuts overlay", f"Could not find {CONFIG_PATH}")
            self.quit()
            return

        self.window = self.build_ui(shortcuts)
        self.window.connect("close-request", self.on_close_request)
        self.window.present()

    def on_close_request(self, window: Gtk.ApplicationWindow) -> bool:
        self.window = None
        self.quit()
        return False


def main() -> int:
    signal.signal(signal.SIGINT, signal.SIG_DFL)
    app = ShortcutOverlay()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
