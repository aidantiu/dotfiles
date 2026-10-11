# Source before calling gsettings from a shell that may live inside the
# Alacritty snap. The snap exports GIO_MODULE_DIR without the dconf module, so
# gsettings silently falls back to an in-memory backend and nothing persists;
# its XDG_DATA_DIRS also shadows the system GSettings schemas.
if [ -n "${SNAP:-}" ]; then
  unset GIO_MODULE_DIR GDK_PIXBUF_MODULEDIR GDK_PIXBUF_MODULE_FILE LD_LIBRARY_PATH XDG_CACHE_HOME
  export XDG_DATA_DIRS=/usr/share/ubuntu:/usr/share/gnome:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:/var/lib/snapd/desktop
fi
