# ymnwricmp — sourced by install-linux.sh; link() is in scope.

# Wayland session: automax.py uses Wnck (X11 only) and segfaults without this.
link hosts/ymnwricmp/systemd/nightswim-automax.service.d/wayland.conf \
  "$HOME/.config/systemd/user/nightswim-automax.service.d/wayland.conf"
systemctl --user daemon-reload 2>/dev/null || true
