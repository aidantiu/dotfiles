#!/usr/bin/python3
"""Maximize every new Alacritty window and give it a workspace of its own.

The WM (GNOME 46 + Forge/tiling-assistant) ignores Alacritty's
startup_mode = "Maximized", and with decorations = "None" there is no title
bar to double-click. A new window opened on a busy workspace is moved to the
empty workspace GNOME keeps at the end (dynamic workspaces) and that workspace
is activated. Only the primary monitor switches workspaces (mutter
workspaces-only-on-primary), so windows on other monitors never count as
"busy", and a terminal opened on another monitor never moves.

Toggle with `nsws on|off|toggle` (flag file FLAG, read on every new window).
Run as a user service: nightswim/systemd/nightswim-automax.service
"""
import os

import gi
gi.require_version("Wnck", "3.0")
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkX11", "3.0")
from gi.repository import Gdk, GdkX11, GLib, Gtk, Wnck

CLASS = "Alacritty"
FLAG = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
                    "nightswim", "new-workspace")


def new_workspace_enabled(path=FLAG):
    try:
        with open(path) as f:
            return f.read().strip() != "off"
    except OSError:
        return True   # default: on


def maximize_later(win):
    # The WM/tilers sometimes undo an early maximize while placing the window,
    # so re-assert it a few times — only during the first ~2s after opening,
    # never later (Super+Down / restore keep working).
    def go():
        if not win.is_maximized():
            win.maximize()
        return False
    for ms in (150, 500, 1000, 2000):
        GLib.timeout_add(ms, go)


def is_app_window(w):
    return w.get_window_type() == Wnck.WindowType.NORMAL and not w.is_skip_tasklist()


def on_primary_monitor(win):
    display = Gdk.Display.get_default()
    x, y, w, h = win.get_geometry()
    monitor = display.get_monitor_at_point(x + w // 2, y + h // 2)
    has_primary = any(display.get_monitor(i).is_primary() for i in range(display.get_n_monitors()))
    return monitor.is_primary() if has_primary else True   # no primary set: single screen


def should_move(win, ws, windows, on_primary, enabled):
    """Move a new terminal off `ws` only if the toggle is on, it opened on the
    primary monitor, and another app window on the primary monitor is already there.
    Pinned windows (e.g. everything on a secondary monitor) never count."""
    if not enabled or not on_primary(win):
        return False
    return any(w is not win and is_app_window(w) and not w.is_pinned()
               and w.is_on_workspace(ws) and on_primary(w) for w in windows)


def own_workspace(screen, win):
    ws = win.get_workspace() or screen.get_active_workspace()
    if not should_move(win, ws, screen.get_windows(), on_primary_monitor, new_workspace_enabled()):
        return
    empty = screen.get_workspace(screen.get_workspace_count() - 1)
    win.move_to_workspace(empty)

    # Like maximize, the switch can be undone while the WM places the window:
    # re-assert it during the first ~2s only (same window as maximize).
    def follow():
        target = win.get_workspace()
        if target and screen.get_active_workspace() != target:
            now = GdkX11.x11_get_server_time(Gdk.get_default_root_window())
            target.activate(now)
            win.activate(now)
        return False
    follow()
    for ms in (150, 400, 800, 1200, 1600, 2000):
        GLib.timeout_add(ms, follow)


def on_open(screen, win):
    if win.get_class_group_name() == CLASS and is_app_window(win):
        own_workspace(screen, win)
        maximize_later(win)


if __name__ == "__main__":
    screen = Wnck.Screen.get_default()
    screen.force_update()
    screen.connect("window-opened", on_open)
    Gtk.main()
