#!/usr/bin/env python3
"""Build the mouse cursor theme hypr-cursors from palette.toml (owner, 2026-10-16).

Shapes: Catppuccin's cursors (based on Volantes; package catppuccin-cursors-mocha from
chaotic-aur, GPL-2.0), the peach variant, whose layout is already the wanted one: a coloured body
with a dark edge. Peach (#fab387) becomes the palette's accent, the darks (#1e1e2e, the edge;
#232627, a detail line on the pencil) become on_accent, and every blurred layer goes: those are
the drop shadows (style rules: no shadow). hyprcursor-util packs the result into
~/.local/share/icons/hypr-cursors, outside the repo: it is generated, and Catppuccin's files are
GPL. wallpaper-apply runs this after generate.py and shows it with `hyprctl setcursor`;
hyprland.lua sets HYPRCURSOR_THEME for the next login.
"""
import re
import shutil
import subprocess
import sys
import tempfile
import tomllib
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path("/usr/share/icons/catppuccin-mocha-peach-cursors/hyprcursors")
NAME = "hypr-cursors"
DEST = Path.home() / ".local/share/icons" / NAME

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


def main():
    ui = tomllib.loads((ROOT / "palette/palette.toml").read_text())["ui"]
    if not SOURCE.is_dir():
        sys.exit(f"cursors.py: {SOURCE} is missing (package catppuccin-cursors-mocha); cursor unchanged")
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
        # Swap the whole folder, so a running Hyprland never sees half a theme.
        DEST.parent.mkdir(parents=True, exist_ok=True)
        new, old = DEST.with_name(f".{NAME}.new"), DEST.with_name(f".{NAME}.old")
        shutil.rmtree(new, ignore_errors=True)
        shutil.rmtree(old, ignore_errors=True)
        shutil.copytree(built, new)
        if DEST.exists():
            DEST.rename(old)
        new.rename(DEST)
        shutil.rmtree(old, ignore_errors=True)
    print(f"wrote {DEST}")


if __name__ == "__main__":
    main()
