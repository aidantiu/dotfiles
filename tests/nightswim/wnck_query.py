#!/usr/bin/python3
"""Test helper. `wnck_query.py state <title>` → "active=<i> win=<i> others=<n>"
(others = normal windows sharing the window's workspace).
`wnck_query.py activate <i>` → switch to workspace i.
`wnck_query.py busy <i>` → number of normal windows on workspace i."""
import sys, gi
gi.require_version("Wnck", "3.0"); gi.require_version("Gdk", "3.0"); gi.require_version("GdkX11", "3.0")
from gi.repository import Wnck, GdkX11, Gdk

s = Wnck.Screen.get_default(); s.force_update()
if sys.argv[1] == "activate":
    ws = s.get_workspace(int(sys.argv[2]))
    ws.activate(GdkX11.x11_get_server_time(Gdk.get_default_root_window()))
    s.force_update(); sys.exit(0)
if sys.argv[1] == "busy":
    ws = s.get_workspace(int(sys.argv[2]))
    print(sum(1 for w in s.get_windows() if ws and w.is_on_workspace(ws)
              and w.get_window_type() == Wnck.WindowType.NORMAL and not w.is_skip_tasklist()))
    sys.exit(0)
win = next((w for w in s.get_windows() if w.get_name() == sys.argv[2]), None)
if win is None:
    print("missing"); sys.exit(1)
ws = win.get_workspace()
others = [w for w in s.get_windows() if w != win and ws and w.is_on_workspace(ws)
          and w.get_window_type() == Wnck.WindowType.NORMAL and not w.is_skip_tasklist()]
print(f"active={s.get_active_workspace().get_number()} win={ws.get_number() if ws else -1} others={len(others)}")
