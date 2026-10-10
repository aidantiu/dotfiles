#!/usr/bin/python3
"""Maximize every new Alacritty window.

The WM (GNOME 46 + Forge/tiling-assistant) ignores Alacritty's
startup_mode = "Maximized", and with decorations = "None" there is no title
bar to double-click. Run as a user service: nightswim/systemd/nightswim-automax.service
"""
import gi
gi.require_version("Wnck", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk, Wnck

CLASS = "Alacritty"


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


def on_open(_screen, win):
    if win.get_class_group_name() == CLASS and win.get_window_type() == Wnck.WindowType.NORMAL:
        maximize_later(win)


screen = Wnck.Screen.get_default()
screen.force_update()
screen.connect("window-opened", on_open)
Gtk.main()
