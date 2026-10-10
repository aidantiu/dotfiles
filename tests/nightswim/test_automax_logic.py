"""Move/stay decision in nightswim/automax.py, with fake windows (no second monitor needed)."""
import os, sys, tempfile
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "nightswim"))
import automax  # must not start the GTK main loop on import

NORMAL = automax.Wnck.WindowType.NORMAL
fails = 0
def check(name, cond):
    global fails
    print(("ok   " if cond else "FAIL ") + name); fails += 0 if cond else 1

class Win:
    def __init__(self, ws, primary=True, pinned=False, kind=NORMAL, skip=False):
        self.ws, self.primary, self.pinned, self.kind, self.skip = ws, primary, pinned, kind, skip
    def is_on_workspace(self, ws): return self.pinned or self.ws == ws
    def is_pinned(self): return self.pinned
    def get_window_type(self): return self.kind
    def is_skip_tasklist(self): return self.skip

on_primary = lambda w: w.primary
new = Win(0)

check("busy primary workspace → move", automax.should_move(new, 0, [new, Win(0)], on_primary, True))
check("empty workspace → stay", not automax.should_move(new, 0, [new], on_primary, True))
check("only second-monitor windows (pinned) → stay",
      not automax.should_move(new, 0, [new, Win(0, primary=False, pinned=True)], on_primary, True))
check("only second-monitor windows (unpinned) → stay",
      not automax.should_move(new, 0, [new, Win(0, primary=False)], on_primary, True))
check("new terminal on second monitor → stay (don't switch main screen)",
      not automax.should_move(Win(0, primary=False), 0, [Win(0)], on_primary, True))
check("panels/docks don't count as busy",
      not automax.should_move(new, 0, [new, Win(0, skip=True)], on_primary, True))
check("toggle off → stay", not automax.should_move(new, 0, [new, Win(0)], on_primary, False))

d = tempfile.mkdtemp(); f = os.path.join(d, "new-workspace")
check("no flag file → on", automax.new_workspace_enabled(f))
open(f, "w").write("off\n"); check("flag off → off", not automax.new_workspace_enabled(f))
open(f, "w").write("on\n");  check("flag on → on", automax.new_workspace_enabled(f))
sys.exit(1 if fails else 0)
