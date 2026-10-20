#!/usr/bin/env python3
"""make-theme.py OUTDIR PALETTE.toml: the GRUB menu theme (owner, 2026-10-20: "Boot, login and
lock" design, idea E; first version 2026-10-15).

The desktop's frame, as on the splash, the login and the lock: the frame colour (the bar colour
with 8% of the accent) round a solid ground with rounded inner corners, the top side the bar's
band. In the ground the entries as tall tiles, one under the other: idea E puts them side by side,
but GRUB's boot_menu only lists top to bottom (the owner chose rows). A tile is the frame colour,
the selected one the accent tint with its name in the accent (one style for every entry: GRUB has
a single selected_item_pixmap_style). Each tile's badge comes from the entry's --class
(icons/<class>.png): Arch's logo in the accent, Windows' in hue4; the Advanced submenu and the
firmware entry have no class, so no badge. Under the tiles the countdown as a bar filling in the
accent, and the keys as chips; the band holds "Starting in N s" as a chip. GRUB can't draw a
shape behind a label, so the chips' fills, the frame and the ground are one background image,
the labels laid over them. Sizes are the desktop's times its 4/3 scale, for the 2560x1600 laptop
panel GRUB draws on (GRUB_GFXMODE=auto); on another size the image stretches and the chips drift.
Writes theme.txt, background.png, the styled-box PNGs (GRUB manual, "Styled Boxes": 9 slices,
edges stretched), icons/ and the fonts (grub-mkfont; grub-mkconfig loads every .pf2 next to
theme.txt). Run by install.sh.
"""
import os
import re
import subprocess
import sys
import tomllib
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

out, palette_path = sys.argv[1], sys.argv[2]
with open(palette_path, "rb") as f:
    palette = tomllib.load(f)
ui = palette["ui"]
# A palette.toml from before the hues: the default's (as palette/generate.py does).
hues = palette.get("hues") or tomllib.loads(
    (Path(__file__).resolve().parent.parent / "palette/palette-default.toml").read_text())["hues"]
os.makedirs(os.path.join(out, "icons"), exist_ok=True)

FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
FAMILY = "JetBrains Mono"
LOGO_SVG = "/usr/share/pixmaps/archlinux-logo.svg"  # one fill, #1793d1
SCALE = 4 / 3
SCREEN_W, SCREEN_H = 2560, 1600


def px(n):
    return round(n * SCALE)


SIDE, BAND, RADIUS = px(10), px(44), px(18)  # Settings.look
SIZES = {"item": px(16), "chip": px(13), "small": px(12)}
SS = 4  # supersampling, for smooth curves


def rgb(hex_colour):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, amount):
    """b over a at this opacity, as Qt.tint does (Edge.qml)."""
    a = rgb(a) if isinstance(a, str) else a
    b = rgb(b) if isinstance(b, str) else b
    return tuple(round(x + (y - x) * amount) for x, y in zip(a, b))


def hexed(colour):
    return "#%02x%02x%02x" % colour


frame = mix(ui["bg"], ui["accent"], 0.08)  # Edge.fill
control = mix(frame, ui["fg"], 0.06)  # Edge.control
accent_tint = mix(frame, ui["accent"], 0.22)  # Edge.accentTint
ground = rgb(ui["bg"])


def rounded_image(w, h, r, colour):
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), r * SS, fill=colour + (255,))
    return big.resize((w, h), Image.LANCZOS)


def box(prefix, colour, r):
    """A rounded styled box: corners r square, edges r thick and 1 long, a 1px centre. GRUB draws
    the edges outside the content, so a box is r larger than its content on every side."""
    whole = rounded_image(2 * r + 1, 2 * r + 1, r, colour)
    cuts = {"nw": (0, 0, r, r), "n": (r, 0, r + 1, r), "ne": (r + 1, 0, 2 * r + 1, r),
            "w": (0, r, r, r + 1), "c": (r, r, r + 1, r + 1), "e": (r + 1, r, 2 * r + 1, r + 1),
            "sw": (0, r + 1, r, 2 * r + 1), "s": (r, r + 1, r + 1, 2 * r + 1),
            "se": (r + 1, r + 1, 2 * r + 1, 2 * r + 1)}
    for name, cut in cuts.items():
        whole.crop(cut).save(os.path.join(out, f"{prefix}_{name}.png"))


# Fonts: Basic Latin and Latin-1, the arrows of the key chips; small bitmap fonts.
for size in sorted(set(SIZES.values())):
    subprocess.run(["grub-mkfont", "-s", str(size), "-n", FAMILY,
                    "-r", "0x20-0x7E,0xA0-0x17F,0x2022-0x2022,0x2190-0x2193",
                    "-o", os.path.join(out, f"jetbrains-{size}.pf2"), FONT], check=True)
fonts = {name: f"{FAMILY} Regular {size}" for name, size in SIZES.items()}
metrics = {name: ImageFont.truetype(FONT, size) for name, size in SIZES.items()}


def text_width(name, text):
    return round(metrics[name].getlength(text))


def text_top(name, top, height):
    """A label's top so its text sits in the middle of a box this tall (GRUB draws a label's
    text with its ascent from the label's top)."""
    ascent, descent = metrics[name].getmetrics()
    return top + (height - ascent - descent) // 2


# The tiles. Their boxes stretch RADIUS past the content, so the content is the tile less two
# radii and the spacing the gap plus two radii.
W = px(520)
TILE_H, TILE_GAP, ROWS = px(96), px(16), 4  # Arch, Advanced, Windows, UEFI (GRUB scrolls if more)
ITEM_H = TILE_H - 2 * RADIUS
SPACING = TILE_GAP + 2 * RADIUS
MENU_H = ROWS * TILE_H + (ROWS - 1) * TILE_GAP
BADGE = ITEM_H  # fills the content's height: RADIUS above and below in the tile
box("item", frame, RADIUS)
box("select", accent_tint, RADIUS)
Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(os.path.join(out, "menu_c.png"))  # no menu box

# The countdown bar and the key chips under the tiles.
BAR_H, BAR_GAP = px(6), px(24)
box("bar", frame, BAR_H // 2)
box("fill", rgb(ui["accent"]), BAR_H // 2)
CHIP_H, CHIP_PAD, CHIP_GAP = px(26), px(10), px(6)
keys = [("↑↓", "choose"), ("Enter", "boot"), ("e", "edit"), ("c", "console")]

cx = SCREEN_W // 2
cy = BAND + (SCREEN_H - BAND - SIDE) // 2
stack = MENU_H + BAR_GAP + BAR_H + BAR_GAP + CHIP_H
menu_top = cy - stack // 2
bar_top = menu_top + MENU_H + BAR_GAP
keys_top = bar_top + BAR_H + BAR_GAP
left = cx - W // 2

# Badges: a rounded square in the hue's tint, the logo in the hue.
def badge(name, hue, draw_glyph):
    img = rounded_image(BADGE, BADGE, px(16), mix(frame, hue, 0.3))
    draw_glyph(img, rgb(hue))
    img.save(os.path.join(out, "icons", f"{name}.png"))


def arch_logo(img, colour):
    with open(LOGO_SVG) as f:
        svg = f.read().replace("#1793d1", hexed(colour))
    # The pixmap's first <path> is the logo; the others draw a small trademark sign beside it.
    for extra in re.findall(r"<path\b.*?/>", svg, flags=re.S)[1:]:
        svg = svg.replace(extra, "")
    size = px(36)
    logo = os.path.join(out, "logo.tmp.png")
    subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), "-o", logo], input=svg.encode(), check=True)
    with Image.open(logo) as glyph:
        img.alpha_composite(glyph.convert("RGBA"), ((BADGE - size) // 2, (BADGE - size) // 2))
    os.remove(logo)


def windows_logo(img, colour):
    """Four squares, as the design's glyph (filled: badges don't change when selected)."""
    size, gap = px(30), px(3)
    half = (size - gap) // 2
    big = Image.new("RGBA", (BADGE * SS, BADGE * SS), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    x0 = y0 = (BADGE - size) // 2
    for dx in (0, half + gap):
        for dy in (0, half + gap):
            draw.rounded_rectangle(((x0 + dx) * SS, (y0 + dy) * SS, (x0 + dx + half) * SS - 1,
                                    (y0 + dy + half) * SS - 1), px(2) * SS, fill=colour + (255,))
    img.alpha_composite(big.resize((BADGE, BADGE), Image.LANCZOS))


badge("arch", ui["accent"], arch_logo)
badge("windows", hues["hue4"], windows_logo)

# The background: frame, ground, and the chips' fills.
bg = Image.new("RGBA", (SCREEN_W, SCREEN_H), frame + (255,))
bg.alpha_composite(rounded_image(SCREEN_W - 2 * SIDE, SCREEN_H - BAND - SIDE, RADIUS, ground), (SIDE, BAND))
countdown = "Starting in %d s"
band_chip_w = text_width("chip", countdown % 10) + 2 * px(12)  # room for two digits
band_chip_h = px(32)
band_chip = (cx - band_chip_w // 2, (BAND - band_chip_h) // 2)
bg.alpha_composite(rounded_image(band_chip_w, band_chip_h, px(8), control), band_chip)
labels = []
widths = [text_width("small", k) + CHIP_GAP + text_width("small", word) + 2 * CHIP_PAD for k, word in keys]
x = cx - (sum(widths) + (len(keys) - 1) * CHIP_GAP) // 2
for (key, word), w in zip(keys, widths):
    bg.alpha_composite(rounded_image(w, CHIP_H, px(8), frame), (x, keys_top))
    labels.append((x + CHIP_PAD, key, ui["fg"]))
    labels.append((x + CHIP_PAD + text_width("small", key) + CHIP_GAP, word, ui["fg_muted"]))
    x += w + CHIP_GAP
bg.convert("RGB").save(os.path.join(out, "background.png"))

key_top = text_top("small", keys_top, CHIP_H)
key_labels = "".join(f"""
+ label {{
  left = {lx}
  top = {key_top}
  width = {text_width("small", text) + 4}
  text = "{text}"
  font = "{fonts['small']}"
  color = "{colour}"
}}
""" for lx, text, colour in labels)

theme = f"""# Generated by grub/make-theme.py from palette/palette.toml. Do not edit.
title-text: ""
desktop-image: "background.png"
desktop-color: "{hexed(frame)}"
terminal-font: "{fonts['item']}"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

+ boot_menu {{
  left = {left}
  top = {menu_top}
  width = {W}
  height = {MENU_H}
  menu_pixmap_style = "menu_*.png"
  item_pixmap_style = "item_*.png"
  selected_item_pixmap_style = "select_*.png"
  item_font = "{fonts['item']}"
  item_color = "{ui['fg']}"
  selected_item_color = "{ui['accent']}"
  item_height = {ITEM_H}
  item_padding = 0
  item_spacing = {SPACING}
  icon_width = {BADGE}
  icon_height = {BADGE}
  item_icon_space = {px(18)}
  scrollbar = false
}}

+ label {{
  left = {band_chip[0]}
  top = {text_top("chip", band_chip[1], band_chip_h)}
  width = {band_chip_w}
  align = "center"
  id = "__timeout__"
  text = "{countdown}"
  font = "{fonts['chip']}"
  color = "{ui['fg_muted']}"
}}

+ progress_bar {{
  left = {left}
  top = {bar_top}
  width = {W}
  height = {BAR_H}
  id = "__timeout__"
  bar_style = "bar_*.png"
  highlight_style = "fill_*.png"
  highlight_overlay = true  # the fill over the track's ends too: the track is all corners
  text = ""
}}
{key_labels}"""
with open(os.path.join(out, "theme.txt"), "w") as f:
    f.write(theme)
