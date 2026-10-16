#!/usr/bin/env python3
"""Build the mouse cursor theme hypr-cursors from palette.toml (owner, 2026-10-16).

Shapes: Catppuccin's cursors (based on Volantes; package catppuccin-cursors-mocha from
chaotic-aur, GPL-2.0), the peach variant, whose layout is already the wanted one: a coloured body
with a dark edge. Peach (#fab387) becomes the palette's accent, the darks (#1e1e2e, the edge;
#232627, a detail line on the pencil) become on_accent, and every blurred layer goes: those are
the drop shadows (style rules: no shadow). Two formats go into ~/.local/share/icons/hypr-cursors,
outside the repo (generated, and Catppuccin's files are GPL):
  hyprcursors/  Hyprland's own cursor (hyprcursor), packed by hyprcursor-util from the SVGs.
  cursors/      XCursor, for apps that draw their own cursor (X11 apps through XWayland, some
                Electron/Qt apps): bitmaps from rsvg-convert, packed by xcursorgen
                (xorg-xcursorgen), plus a symlink for every other name a shape answers to.
An app asking for size 24 gets a 32 px image: Catppuccin draws its shapes at 75% of the canvas
(nominal_size = 0.75 in meta.hl), so the shape itself is 24 px, as in Hyprland. wallpaper-apply
runs this after generate.py and shows it with `hyprctl setcursor`; hyprland.lua sets
HYPRCURSOR_THEME and XCURSOR_THEME for the next login.
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import xml.etree.ElementTree as ET
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path("/usr/share/icons/catppuccin-mocha-peach-cursors/hyprcursors")
NAME = "hypr-cursors"
DEST = Path.home() / ".local/share/icons" / NAME
# XCursor sizes apps can ask for: XCURSOR_SIZE 24 at scale 1 (external screens), 4/3 (the laptop),
# 2 and 8/3. An app takes the nearest one.
XCURSOR_SIZES = (24, 32, 48, 64)

# Catppuccin colour -> palette role. One pass, so a new colour is never replaced again.
COLOURS = {"#fab387": "accent", "#1e1e2e": "on_accent", "#232627": "on_accent"}
COLOUR = re.compile("|".join(COLOURS), re.I)
# A drawn element (one tag, self-closing) that uses a filter: Catppuccin's blurred drop shadows.
SHADOW = re.compile(r"<(?:path|circle|rect|ellipse)\b[^>]*filter:url\([^>]*/>")


def recolour(svg: str, ui: dict) -> str:
    svg = SHADOW.sub("", svg)
    if "filter:url" in svg:
        raise ValueError("a blurred layer is left over")
    svg = COLOUR.sub(lambda m: ui[COLOURS[m.group(0).lower()]], svg)
    ET.fromstring(svg)  # still a valid SVG
    return svg


def read_meta(text: str) -> dict:
    """A shape's meta.hl: hotspot (fractions of the image), nominal size, frames, other names."""
    meta = {"hotspot_x": 0.0, "hotspot_y": 0.0, "nominal_size": 1.0, "frames": [], "names": []}
    for line in text.splitlines():
        key, _, value = line.partition("=")
        key, value = key.strip(), value.split("#")[0].strip()
        if key in ("hotspot_x", "hotspot_y", "nominal_size"):
            meta[key] = float(value)
        elif key == "define_size":  # size, file[, delay in ms]; size 0 = an SVG for every size
            size, file, *delay = (part.strip() for part in value.split(","))
            if size != "0":
                raise ValueError(f"define_size {size}: only SVG shapes are handled")
            meta["frames"].append((file, int(delay[0]) if delay else 0))
        elif key == "define_override":
            meta["names"].append(value)
    return meta


def xcursor_theme(shapes: Path, out: Path, scratch: Path):
    """XCursor files for every shape folder in `shapes` (meta.hl + recoloured SVGs) into out/cursors."""
    cursors = out / "cursors"
    cursors.mkdir(parents=True)
    configs, renders = {}, []
    for shape in sorted(p for p in shapes.iterdir() if p.is_dir()):
        meta = read_meta((shape / "meta.hl").read_text())
        lines = []
        for size in XCURSOR_SIZES:
            px = round(size / meta["nominal_size"])
            hx = min(px - 1, round(meta["hotspot_x"] * px))
            hy = min(px - 1, round(meta["hotspot_y"] * px))
            for file, delay in meta["frames"]:
                png = scratch / f"{shape.name}.{Path(file).stem}.{px}.png"
                renders.append((shape / file, png, px))
                lines.append(f"{size} {hx} {hy} {png}" + (f" {delay}" if delay else ""))
        configs[shape.name] = (lines, meta["names"])

    def render(job):
        svg, png, px = job
        subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), "-o", str(png), str(svg)], check=True)

    with ThreadPoolExecutor(os.cpu_count()) as pool:
        list(pool.map(render, renders))
    for name, (lines, _) in configs.items():
        subprocess.run(["xcursorgen", "-", str(cursors / name)], input="\n".join(lines) + "\n",
                       text=True, check=True)
    for name, (_, others) in configs.items():  # left_ptr, arrow, ... -> default
        for other in others:
            if not (cursors / other).exists():
                (cursors / other).symlink_to(name)
    (out / "index.theme").write_text(
        f"[Icon Theme]\nName={NAME}\n"
        "Comment=Catppuccin's cursors (Volantes) in the desktop palette, no shadow\n"
        "Inherits=Adwaita\n"  # any name missing here falls back to Adwaita's
    )


def main():
    ui = tomllib.loads((ROOT / "palette/palette.toml").read_text())["ui"]
    if not SOURCE.is_dir():
        sys.exit(f"cursors.py: {SOURCE} is missing (package catppuccin-cursors-mocha); cursor unchanged")
    for tool, package in (("hyprcursor-util", "hyprcursor"), ("rsvg-convert", "librsvg"), ("xcursorgen", "xorg-xcursorgen")):
        if not shutil.which(tool):
            sys.exit(f"cursors.py: {tool} is missing (package {package}); cursor unchanged")
    with tempfile.TemporaryDirectory() as tmp:
        work = Path(tmp) / "source"
        for hlc in sorted(SOURCE.glob("*.hlc")):  # one zip per shape: meta.hl and its SVGs
            shape = work / "hyprcursors" / hlc.stem
            shape.mkdir(parents=True)
            with zipfile.ZipFile(hlc) as z:
                for member in z.namelist():
                    name, data = Path(member).name, z.read(member)
                    if name.endswith(".svg"):
                        try:
                            data = recolour(data.decode(), ui).encode()
                        except (ValueError, ET.ParseError) as err:
                            sys.exit(f"cursors.py: {hlc.name}/{name}: {err}; cursor unchanged")
                    (shape / name).write_bytes(data)
        (work / "manifest.hl").write_text(
            f"name = {NAME}\n"
            "description = Catppuccin's cursors (Volantes) in the desktop palette, no shadow\n"
            "version = 1\n"
            "cursors_directory = hyprcursors\n"
        )
        subprocess.run(["hyprcursor-util", "--create", str(work), "--output", tmp],
                       check=True, stdout=subprocess.DEVNULL)
        built = Path(tmp) / f"theme_{NAME}"
        scratch = Path(tmp) / "png"
        scratch.mkdir()
        try:
            xcursor_theme(work / "hyprcursors", built, scratch)
        except (ValueError, subprocess.CalledProcessError) as err:
            sys.exit(f"cursors.py: XCursor: {err}; cursor unchanged")
        # Swap the whole folder, so a running Hyprland never sees half a theme.
        DEST.parent.mkdir(parents=True, exist_ok=True)
        new, old = DEST.with_name(f".{NAME}.new"), DEST.with_name(f".{NAME}.old")
        shutil.rmtree(new, ignore_errors=True)
        shutil.rmtree(old, ignore_errors=True)
        shutil.copytree(built, new, symlinks=True)  # keep the other names as links
        if DEST.exists():
            DEST.rename(old)
        new.rename(DEST)
        shutil.rmtree(old, ignore_errors=True)
    print(f"wrote {DEST}")


if __name__ == "__main__":
    main()
