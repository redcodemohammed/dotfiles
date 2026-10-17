#!/usr/bin/env python3
"""Write palette/palette.toml from a wallpaper image, then let generate.py do the rest.

Keeps the design system's structure (dark, grayscale chrome, one accent):
- accent: the image's most vivid hue, at the lightness of the default amber (OKLCH L 0.78). Reds
  (within 20 degrees of the alert red's hue) are lit at L 0.72 instead, because at 0.78 red turns
  coral or salmon; the alert red stays as it is (owner, 2026-10-17, overriding the spec's "red
  means live or failed only": a red wallpaper gives a red accent; there used to be a keep-out
  zone pushing red toward orange). A soft image (fewer than 1% vivid pixels, but visibly coloured)
  takes its warm highlight (reds, oranges, pinks: a sunset on a blue dusk) when at least 0.5% of
  it is warm, else its most colourful soft hue (owner, 2026-10-17: these used to turn gray). Only
  an image without colour (black and white) gets a light gray accent, a monochrome desktop.
- neutrals (bg, surfaces, border, text): the default palette's exact lightness, faintly tinted
  toward the image's dominant hue, so contrast stays what it was.
- alert and the ANSI colours stay as in the default, except yellow (= accent, unless the accent
  is gray: a gray "yellow" would hide warnings) and the grays (= the tinted neutrals).
Every pair that matters is checked against WCAG contrast and nudged if needed.

  from-wallpaper.py <image>     write palette.toml from the image
  from-wallpaper.py --default   restore palette.toml from palette-default.toml
"""
import math
import sys
import tomllib
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
DEFAULT = HERE / "palette-default.toml"
TARGET = HERE / "palette.toml"

ACCENT_L = 0.78               # lightness of the default amber
ACCENT_C = (0.10, 0.17)       # chroma range for the accent
ALERT_HUE = 25.0              # OKLCH hue of the alert red
RED_RANGE = 20.0              # accent hues this close to the alert red's count as red
RED_L = 0.72                  # their lightness: still red, lighter than alert (#e5484d, L 0.63)
GRAY_ACCENT = "#bebebe"       # no colour: OKLCH L 0.80, no chroma (contrast 10 on bg)
SOFT_C = 0.035                # a soft image's coloured pixels: at least this chroma
WARM_SHARE = 0.005            # warm soft pixels needed for the warm highlight to win (0.5%)


def is_warm(h):
    return h >= 330 or h <= 80  # pinks, reds, oranges, ambers
TINT_MAX = 0.012              # neutral tint chroma at most (barely there)
NEUTRALS = ("bg", "surface", "surface_selected", "border", "fg", "fg_muted", "fg_dim")


# --- colour maths: sRGB <-> OKLab/OKLCH (Bjorn Ottosson), WCAG contrast ---

def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (1, 3, 5))


def rgb_hex(rgb):
    return "#" + "".join(f"{round(max(0, min(1, c)) * 255):02x}" for c in rgb)


def rgb_oklch(rgb):
    r, g, b = (_lin(c) for c in rgb)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, math.hypot(A, B), math.degrees(math.atan2(B, A)) % 360


def oklch_rgb(L, C, h):
    A, B = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3
    m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3
    s = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return tuple(_gam(max(0.0, c)) for c in (r, g, b))


def in_gamut(L, C, h):
    A, B = C * math.cos(math.radians(h)), C * math.sin(math.radians(h))
    l = (L + 0.3963377774 * A + 0.2158037573 * B) ** 3
    m = (L - 0.1055613458 * A - 0.0638541728 * B) ** 3
    s = (L - 0.0894841775 * A - 1.2914855480 * B) ** 3
    rgb = (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    return all(-1e-4 <= c <= 1 + 1e-4 for c in rgb)


def oklch_hex(L, C, h):
    while C > 0 and not in_gamut(L, C, h):  # keep the hue, give up chroma
        C -= 0.002
    return rgb_hex(oklch_rgb(L, max(C, 0), h))


def luminance(h):
    r, g, b = (_lin(c) for c in hex_rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def hue_dist(a, b):
    return abs((a - b + 180) % 360 - 180)


# --- reading the image ---

def analyse(path):
    img = Image.open(path).convert("RGB")
    img.thumbnail((96, 96))
    data = img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata()
    pixels = [rgb_oklch(tuple(c / 255 for c in px)) for px in data]

    # Dominant hue for the neutral tint: every coloured pixel, weighted by its chroma.
    def mean_hue(samples):
        x = sum(w * math.cos(math.radians(h)) for h, w in samples)
        y = sum(w * math.sin(math.radians(h)) for h, w in samples)
        return math.degrees(math.atan2(y, x)) % 360 if (x or y) else None

    base_hue = mean_hue([(h, C) for L, C, h in pixels if C > 0.02])
    avg_chroma = sum(C for _, C, _ in pixels) / len(pixels)

    # Accent: the hue band (10 degrees) holding the most vivid pixels (sum of chroma squared).
    vivid = [(L, C, h) for L, C, h in pixels if C >= 0.06 and 0.3 <= L <= 0.95]
    if len(vivid) < len(pixels) * 0.01:
        # Soft image: its gentler colours count; a warm highlight wins over a larger cool area.
        soft = [(L, C, h) for L, C, h in pixels if C >= SOFT_C and 0.2 <= L <= 0.95]
        warm = [(L, C, h) for L, C, h in soft if is_warm(h)]
        if len(warm) >= len(pixels) * WARM_SHARE:
            vivid = warm
        elif len(soft) >= len(pixels) * 0.01:
            vivid = soft
        else:
            return base_hue, avg_chroma, None, None  # no colour: the gray accent
    bins = [0.0] * 36
    for L, C, h in vivid:
        bins[int(h // 10) % 36] += C * C
    best = max(range(36), key=lambda i: bins[i - 1] + bins[i] + bins[(i + 1) % 36])
    band = [(h, C * C) for L, C, h in vivid if hue_dist(h, best * 10 + 5) <= 15]
    accent_hue = mean_hue(band)
    chromas = sorted(C for L, C, h in vivid if hue_dist(h, accent_hue) <= 15)
    accent_chroma = chromas[int(len(chromas) * 0.8)] if chromas else ACCENT_C[0]
    return base_hue, avg_chroma, accent_hue, accent_chroma


# --- building the palette ---

def build(path):
    default = tomllib.loads(DEFAULT.read_text())
    ui = dict(default["ui"])
    normal = dict(default["ansi"]["normal"])
    bright = dict(default["ansi"]["bright"])
    base_hue, avg_chroma, accent_hue, accent_chroma = analyse(path)

    # Neutrals: same lightness as the default grays, a faint tint of the image's main hue.
    if base_hue is not None:
        tint = min(TINT_MAX, avg_chroma * 0.25)
        for role in NEUTRALS:
            L, _, _ = rgb_oklch(hex_rgb(default["ui"][role]))
            chroma = tint if role in ("bg", "surface", "surface_selected", "border") else tint * 0.5
            ui[role] = oklch_hex(L, chroma, base_hue)

    # Accent: the image's most vivid hue, lit like the default amber (reds a little darker).
    if accent_hue is not None:
        lightness = RED_L if hue_dist(accent_hue, ALERT_HUE) <= RED_RANGE else ACCENT_L
        chroma = max(ACCENT_C[0], min(ACCENT_C[1], accent_chroma))
        ui["accent"] = oklch_hex(lightness, chroma, accent_hue)
        bright["yellow"] = oklch_hex(lightness + 0.04, chroma, accent_hue)
        normal["yellow"] = ui["accent"]
    else:  # too little colour: a monochrome desktop; ANSI yellow stays the default
        ui["accent"] = GRAY_ACCENT
    ui["on_accent"] = ui["bg"]

    # Contrast floors (WCAG): text 7, muted text and accent 4.5, text on the accent 4.5.
    def lift(role, floor, step=0.01):
        L, C, h = rgb_oklch(hex_rgb(ui[role]))
        while contrast(ui[role], ui["bg"]) < floor and L < 0.98:
            L += step
            ui[role] = oklch_hex(L, C, h)
    lift("fg", 7.0)
    lift("fg_muted", 4.5)
    lift("accent", 4.5)
    if contrast(ui["on_accent"], ui["accent"]) < 4.5:
        ui["on_accent"] = "#111111"

    # ANSI grays follow the tinted neutrals; the coloured slots keep their default hues.
    normal["black"] = ui["border"]
    bright["black"] = ui["fg_muted"]
    bright["white"] = ui["fg"]
    L, _, _ = rgb_oklch(hex_rgb(default["ansi"]["normal"]["white"]))
    normal["white"] = oklch_hex(L, rgb_oklch(hex_rgb(ui["fg"]))[1], base_hue or 0)
    return ui, normal, bright


def write(path, ui, normal, bright):
    def table(name, values, note=""):
        rows = "\n".join(f'{k:<16} = "{v}"' for k, v in values.items())
        return f"[{name}]{note}\n{rows}\n"
    checks = (f"# Contrast on bg: fg {contrast(ui['fg'], ui['bg']):.1f}, fg_muted "
              f"{contrast(ui['fg_muted'], ui['bg']):.1f}, accent {contrast(ui['accent'], ui['bg']):.1f}; "
              f"on_accent on accent {contrast(ui['on_accent'], ui['accent']):.1f}.")
    TARGET.write_text(
        f"# Shared palette. Single source of truth for every UI color.\n"
        f"# Generated by palette/from-wallpaper.py from {Path(path).name}; the hand-made palette is\n"
        f"# palette-default.toml (restore it with: from-wallpaper.py --default). Dark only.\n"
        f"{checks}\n\n"
        + table("ui", ui) + "\n"
        + table("ansi.normal", normal) + "\n"
        + table("ansi.bright", bright))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    if sys.argv[1] == "--default":
        TARGET.write_text(DEFAULT.read_text())
        print("palette.toml restored from palette-default.toml")
        return
    ui, normal, bright = build(sys.argv[1])
    write(sys.argv[1], ui, normal, bright)
    print(f"accent {ui['accent']}  bg {ui['bg']}  fg {ui['fg']}  "
          f"(accent contrast {contrast(ui['accent'], ui['bg']):.1f})")


if __name__ == "__main__":
    main()
