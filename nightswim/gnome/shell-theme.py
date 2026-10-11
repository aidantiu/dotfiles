#!/usr/bin/env python3
"""Build the Nightswim GNOME Shell theme from the installed Yaru-dark one.

Every colour in Yaru-dark's stylesheet and SVG assets is remapped onto the
Nightswim palette (nightswim/palette.sh), then nightswim/gnome/shell.css is
appended for the layout touches (translucent bar, rounded cards).
Rebuilding against the system theme keeps selectors in step with the
installed GNOME Shell version.

usage: shell-theme.py [OUT_DIR]   (default ~/.local/share/themes/Nightswim)
"""
import colorsys
import pathlib
import re
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
SRC = pathlib.Path("/usr/share/gnome-shell/theme/Yaru-dark")


def palette():
    pal = {}
    for line in (HERE.parent / "palette.sh").read_text().splitlines():
        m = re.match(r"(NS_\w+)=([0-9a-fA-F]{6})", line)
        if m:
            pal[m[1]] = tuple(int(m[2][i:i + 2], 16) / 255 for i in (0, 2, 4))
    return pal


PAL = palette()
# Yaru's greys are mapped onto a navy→lavender ramp built from the palette:
# its panel/popup darks land on the terminal background, mid greys on the
# surface and muted colours, near-whites on the foreground.
DARK = (0x07 / 255, 0x0a / 255, 0x18 / 255)
LIGHT = (0xe6 / 255, 0xe0 / 255, 0xf2 / 255)
RAMP = [(0.0, DARK), (0.11, PAL["NS_BG"]), (0.28, PAL["NS_SURFACE"]),
        (0.54, PAL["NS_DIM"]), (0.95, PAL["NS_FG"]), (1.0, LIGHT)]


def lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def with_lightness(target, light):
    h, _, s = colorsys.rgb_to_hls(*target)
    return colorsys.hls_to_rgb(h, light, s)


def remap(rgb):
    h, light, s = colorsys.rgb_to_hls(*rgb)
    if s < 0.15 or light < 0.04 or light > 0.97:
        t = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
        for (t0, c0), (t1, c1) in zip(RAMP, RAMP[1:]):
            if t <= t1:
                return lerp(c0, c1, (t - t0) / (t1 - t0))
        return LIGHT
    deg = h * 360
    if deg < 15 or deg >= 330:
        return with_lightness(PAL["NS_RED"], light)
    if deg < 70:  # Yaru orange accent and amber warnings -> gold
        return with_lightness(PAL["NS_GOLD"], light)
    if deg < 170:
        return with_lightness(PAL["NS_GREEN"], light)
    if deg < 260:
        return with_lightness(PAL["NS_BLUE"], light)
    return with_lightness(PAL["NS_LILAC"], light)


def hexify(rgb):
    return "#" + "".join(f"{round(max(0, min(1, c)) * 255):02x}" for c in rgb)


HEX = re.compile(r"#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})\b")
RGBA = re.compile(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)")


def recolor(text):
    def hex_sub(m):
        v = m[1] if len(m[1]) == 6 else "".join(c * 2 for c in m[1])
        return hexify(remap(tuple(int(v[i:i + 2], 16) / 255 for i in (0, 2, 4))))

    def rgba_sub(m):
        r, g, b = (round(c * 255) for c in remap(tuple(int(m[i]) / 255 for i in (1, 2, 3))))
        return f"rgba({r}, {g}, {b}, {m[4]})" if m[4] else f"rgb({r}, {g}, {b})"

    return RGBA.sub(rgba_sub, HEX.sub(hex_sub, text))


def main():
    out = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                       pathlib.Path.home() / ".local/share/themes/Nightswim")
    dst = out / "gnome-shell"
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    for f in SRC.iterdir():
        if f.suffix in (".css", ".svg"):
            (dst / f.name).write_text(recolor(f.read_text()))
    css = dst / "gnome-shell.css"
    css.write_text(css.read_text() + "\n/* ---- Nightswim layout ---- */\n"
                   + (HERE / "shell.css").read_text())
    print(dst)


if __name__ == "__main__":
    main()
