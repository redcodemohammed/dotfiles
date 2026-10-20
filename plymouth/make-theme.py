#!/usr/bin/env python3
"""make-theme.py OUTDIR PALETTE.toml: the Plymouth boot splash (owner, 2026-10-20: "Boot, login and
lock" design, idea F; first version 2026-10-15).

The desktop's frame: the frame colour (the bar colour with 8% of the accent) round a solid ground
with rounded inner corners, the top side the bar's band. The band is the progress: six segments,
one per hue (hue1-hue6), lit left to right as the boot goes, the next one pulsing. The Arch logo
in the accent in the middle of the ground, "Arch Linux" under it; boot messages (fsck and such)
muted near the bottom; a password request as the lock screen's field (the accent tint, a filled
lock, one bullet per key) with its prompt above. Plymouth's script plugin only places, scales and
fades images, so every rounded shape is a PNG made here: the ground is a 1px image stretched to
fill, its four corners laid over it. Sizes are the desktop's times its 4/3 scale, for the 2560x1600
laptop panel. Writes hypr.plymouth, hypr.script and the PNGs. Run by install.sh.
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
hues = [hues[f"hue{i}"] for i in range(1, 7)]
os.makedirs(out, exist_ok=True)

LOGO_SVG = "/usr/share/pixmaps/archlinux-logo.svg"  # one fill, #1793d1
LOCK_FONT = "/usr/share/fonts/TTF/Phosphor-Fill.ttf"
LOCK = ""  # Phosphor lock (Icons.lock in the shell)
SCALE = 4 / 3
SIDE, BAND, RADIUS = round(10 * SCALE), round(44 * SCALE), round(18 * SCALE)  # Settings.look
LOGO = round(96 * SCALE)
SEG_W, SEG_H, SEG_GAP = round(96 * SCALE), round(6 * SCALE), round(6 * SCALE)
FIELD_W, FIELD_H, FIELD_R = round(360 * SCALE), round(52 * SCALE), round(12 * SCALE)
SS = 4  # supersampling, for smooth curves


def rgb(hex_colour):
    return tuple(int(hex_colour[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, amount):
    """b over a at this opacity, as Qt.tint does (Edge.qml)."""
    return tuple(round(x + (y - x) * amount) for x, y in zip(rgb(a) if isinstance(a, str) else a, rgb(b)))


frame = mix(ui["bg"], ui["accent"], 0.08)  # Edge.fill
control = mix(frame, ui["fg"], 0.06)  # Edge.control
accent_tint = tuple(round(x + (y - x) * 0.22) for x, y in zip(frame, rgb(ui["accent"])))  # Edge.accentTint
ground = rgb(ui["bg"])


def rounded(w, h, r, colour, name):
    big = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), r * SS, fill=colour + (255,))
    big.resize((w, h), Image.LANCZOS).save(os.path.join(out, name))


# The ground: one pixel, stretched by the script; its corners, the frame colour with the ground's
# quarter circle, for each of the four.
Image.new("RGB", (1, 1), ground).save(os.path.join(out, "ground.png"))
big = Image.new("RGB", (2 * RADIUS * SS, 2 * RADIUS * SS), frame)
ImageDraw.Draw(big).ellipse((0, 0, 2 * RADIUS * SS - 1, 2 * RADIUS * SS - 1), fill=ground)
circle = big.resize((2 * RADIUS, 2 * RADIUS), Image.LANCZOS)
for name, box in {"tl": (0, 0), "tr": (RADIUS, 0), "bl": (0, RADIUS), "br": (RADIUS, RADIUS)}.items():
    circle.crop(box + (box[0] + RADIUS, box[1] + RADIUS)).save(os.path.join(out, f"corner-{name}.png"))

# The band's progress: a segment per hue, and the unlit one.
for i, hue in enumerate(hues):
    rounded(SEG_W, SEG_H, SEG_H // 2, rgb(hue), f"seg{i}.png")
rounded(SEG_W, SEG_H, SEG_H // 2, control, "seg-off.png")

# The logo, in the accent.
with open(LOGO_SVG) as f:
    svg = f.read().replace("#1793d1", ui["accent"])
# The pixmap's first <path> is the logo; the others draw a small trademark sign beside it.
for extra in re.findall(r"<path\b.*?/>", svg, flags=re.S)[1:]:
    svg = svg.replace(extra, "")
subprocess.run(["rsvg-convert", "-w", str(LOGO), "-h", str(LOGO), "-o", os.path.join(out, "logo.png")],
               input=svg.encode(), check=True)

# A password request: the field and its filled lock.
rounded(FIELD_W, FIELD_H, FIELD_R, accent_tint, "field.png")
size = round(20 * SCALE)
lock = Image.new("RGBA", (size, size), (0, 0, 0, 0))
font = ImageFont.truetype(LOCK_FONT, size)
ImageDraw.Draw(lock).text((size / 2, size / 2), LOCK, font=font, fill=rgb(ui["accent"]) + (255,), anchor="mm")
lock.save(os.path.join(out, "lock.png"))


def script_rgb(colour):
    colour = rgb(colour) if isinstance(colour, str) else colour
    return ", ".join(f"{c / 255:.3f}" for c in colour)


with open(os.path.join(out, "hypr.plymouth"), "w") as f:
    f.write("""[Plymouth Theme]
Name=Hypr
Description=The desktop's frame, the band filling with the hues as it boots (dotfiles plymouth/make-theme.py)
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/hypr
ScriptFile=/usr/share/plymouth/themes/hypr/hypr.script
Font=JetBrainsMono Nerd Font 15
MonospaceFont=JetBrainsMono Nerd Font 15
""")

with open(os.path.join(out, "hypr.script"), "w") as f:
    f.write(f"""# Generated by plymouth/make-theme.py from palette/palette.toml. Do not edit.
Window.SetBackgroundTopColor({script_rgb(frame)});
Window.SetBackgroundBottomColor({script_rgb(frame)});

side = {SIDE};
band = {BAND};
radius = {RADIUS};
x0 = Window.GetX();
y0 = Window.GetY();
w = Window.GetWidth();
h = Window.GetHeight();

# The ground inside the frame, and its rounded corners over it.
ground.image = Image("ground.png").Scale(w - 2 * side, h - band - side);
ground.sprite = Sprite(ground.image);
ground.sprite.SetPosition(x0 + side, y0 + band, 0);
corners[0] = Sprite(Image("corner-tl.png"));
corners[0].SetPosition(x0 + side, y0 + band, 1);
corners[1] = Sprite(Image("corner-tr.png"));
corners[1].SetPosition(x0 + w - side - radius, y0 + band, 1);
corners[2] = Sprite(Image("corner-bl.png"));
corners[2].SetPosition(x0 + side, y0 + h - side - radius, 1);
corners[3] = Sprite(Image("corner-br.png"));
corners[3].SetPosition(x0 + w - side - radius, y0 + h - side - radius, 1);

cx = x0 + w / 2;
cy = y0 + band + (h - band - side) / 2;

logo.image = Image("logo.png");
logo.sprite = Sprite(logo.image);
logo.sprite.SetPosition(cx - logo.image.GetWidth() / 2, cy - logo.image.GetHeight() + 16, 2);
name.image = Image.Text("Arch Linux", {script_rgb(ui['fg_muted'])});
name.sprite = Sprite(name.image);
name.sprite.SetPosition(cx - name.image.GetWidth() / 2, cy + 44, 2);

# The band: six segments, lit up to the boot's progress; the one in progress pulses.
off_image = Image("seg-off.png");
for (i = 0; i < 6; i++)
  {{
    seg_image[i] = Image("seg" + i + ".png");
    segs[i] = Sprite(off_image);
    segs[i].SetPosition(cx - (6 * {SEG_W} + 5 * {SEG_GAP}) / 2 + i * ({SEG_W} + {SEG_GAP}), y0 + (band - {SEG_H}) / 2, 2);
  }}
lit = 0;
fun progress_callback (duration, progress)
  {{
    lit = Math.Int(progress * 6);
    for (i = 0; i < 6; i++)
      {{
        if (i <= lit)
          segs[i].SetImage(seg_image[i]);
        else
          segs[i].SetImage(off_image);
        if (i < lit)
          segs[i].SetOpacity(1);
      }}
  }}
Plymouth.SetBootProgressFunction (progress_callback);

time = 0;
fun refresh_callback ()
  {{
    time++;  # 50 per second
    if (lit < 6)
      segs[lit].SetOpacity(0.35 + 0.65 * (Math.Cos(time / 50 * 2 * 3.14159 / 1.2) + 1) / 2);  # 1.2 s a pulse
  }}
Plymouth.SetRefreshFunction (refresh_callback);

# Messages (fsck and such): muted, centred near the bottom.
message.sprite = Sprite();
fun display_message_callback (text)
  {{
    message.image = Image.Text(text, {script_rgb(ui['fg_muted'])});
    message.sprite.SetImage(message.image);
    message.sprite.SetPosition(cx - message.image.GetWidth() / 2, y0 + h - side - 64, 3);
    message.sprite.SetOpacity(1);
  }}
fun hide_message_callback (text)
  {{
    message.sprite.SetOpacity(0);
  }}
Plymouth.SetDisplayMessageFunction (display_message_callback);
Plymouth.SetHideMessageFunction (hide_message_callback);

# A password request (none expected: no disk encryption): the lock screen's field, the prompt
# above it, one bullet per key.
field.sprite = Sprite(Image("field.png"));
field.sprite.SetOpacity(0);
lock.sprite = Sprite(Image("lock.png"));
lock.sprite.SetOpacity(0);
prompt.sprite = Sprite();
bullets.sprite = Sprite();
fx = cx - {FIELD_W} / 2;
fy = cy + 110;
field.sprite.SetPosition(fx, fy, 3);
lock.sprite.SetPosition(fx + 21, fy + ({FIELD_H} - {round(20 * SCALE)}) / 2, 4);
fun display_password_callback (text, count)
  {{
    prompt.image = Image.Text(text, {script_rgb(ui['fg_muted'])});
    prompt.sprite.SetImage(prompt.image);
    prompt.sprite.SetPosition(cx - prompt.image.GetWidth() / 2, fy - prompt.image.GetHeight() - 16, 4);
    line = "";
    for (i = 0; i < count; i++)
      line = line + "• ";
    bullets.image = Image.Text(line, {script_rgb(ui['fg'])});
    bullets.sprite.SetImage(bullets.image);
    bullets.sprite.SetPosition(fx + 64, fy + ({FIELD_H} - bullets.image.GetHeight()) / 2, 4);
    field.sprite.SetOpacity(1);
    lock.sprite.SetOpacity(1);
    prompt.sprite.SetOpacity(1);
    bullets.sprite.SetOpacity(1);
    name.sprite.SetOpacity(0);
  }}
fun display_normal_callback ()
  {{
    field.sprite.SetOpacity(0);
    lock.sprite.SetOpacity(0);
    prompt.sprite.SetOpacity(0);
    bullets.sprite.SetOpacity(0);
    name.sprite.SetOpacity(1);
  }}
Plymouth.SetDisplayPasswordFunction (display_password_callback);
Plymouth.SetDisplayNormalFunction (display_normal_callback);
""")
