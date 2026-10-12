# ymnwricmp — ThinkPad X1 Carbon 4th gen (i7-6600U, HD 520), Ubuntu 24.04, Wayland.
# Sourced at the end of nightswim/desktop.sh; xs, custom_key, B/BS are in scope.

# Dynamic blur stutters on HD 520 — keep only the static panel/dock blur.
xs $B $BS.overview blur false
xs $B $BS.appfolder blur false

# Vicinae on Alt+Space (taken from GNOME's window menu) instead of Super+Space;
# new windows, Vicinae included, open centred.
gsettings set org.gnome.desktop.wm.keybindings activate-window-menu "[]"
gsettings set org.gnome.mutter center-new-windows true
custom_key nightswim-vicinae 'Nightswim: Vicinae launcher' "$HOME/.local/bin/vicinae toggle" '<Alt>space'

# Small 14" panel: larger UI text (just-perfection hides the a11y icon it adds).
gsettings set org.gnome.desktop.interface text-scaling-factor 1.25
