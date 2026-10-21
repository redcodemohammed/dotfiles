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
fill, its four corners laid over it. Every screen gets its own frame, logo and band (Plymouth
overlaps them on one canvas, so the script spreads them apart); messages and the password go on
the laptop's (2560x1600). Sizes are the desktop's times its 4/3 scale. Writes hypr.plymouth, hypr.script and the PNGs. Run by install.sh.
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
seg_w = {SEG_W};
seg_h = {SEG_H};
seg_gap = {SEG_GAP};
field_w = {FIELD_W};
field_h = {FIELD_H};
lock_size = {round(20 * SCALE)};
off_image = Image("seg-off.png");
for (i = 0; i < 6; i++)
  seg_image[i] = Image("seg" + i + ".png");
logo_image = Image("logo.png");
name_image = Image.Text("Arch Linux", {script_rgb(ui['fg_muted'])});

# Plymouth puts every screen on one canvas, each centred on the largest, so they overlap and
# show slices of one picture. Instead: the screens side by side, apart, each with its own
# frame, logo and band; messages and the password on the laptop's (2560x1600, else the first).
# Plymouth re-centres them when a screen is added, so the refresh lays them out again then.
# A name assigned in a function is the global one only if it exists already (else a new local,
# dropped on return, and its sprites with it), so every name the functions share is made here.
laid = 0;
primary = 0;
placed[0] = 0;
screen_cx[0] = 0;
screen_cy[0] = 0;
screen_bottom[0] = 0;
grounds[0] = NULL;
corners[0] = NULL;
logos[0] = NULL;
names[0] = NULL;
segs[0] = NULL;
lit = 0;
fun count_screens ()
  {{
    n = 0;
    while (Window.GetWidth(n))
      n++;
    return n;
  }}
fun layout ()
  {{
    laid = count_screens();
    primary = 0;
    for (d = 0; d < laid; d++)
      if (Window.GetWidth(d) == 2560 && Window.GetHeight(d) == 1600)
        primary = d;
    left = 0;
    for (d = 0; d < laid; d++)
      {{
        Window.SetX(d, left);
        Window.SetY(d, 0);
        placed[d] = left;
        w = Window.GetWidth(d);
        h = Window.GetHeight(d);
        screen_cx[d] = left + w / 2;
        screen_cy[d] = band + (h - band - side) / 2;
        screen_bottom[d] = h - side;
        # The ground inside the frame, and its rounded corners over it.
        grounds[d] = Sprite(Image("ground.png").Scale(w - 2 * side, h - band - side));
        grounds[d].SetPosition(left + side, band, 0);
        corners[d * 4] = Sprite(Image("corner-tl.png"));
        corners[d * 4].SetPosition(left + side, band, 1);
        corners[d * 4 + 1] = Sprite(Image("corner-tr.png"));
        corners[d * 4 + 1].SetPosition(left + w - side - radius, band, 1);
        corners[d * 4 + 2] = Sprite(Image("corner-bl.png"));
        corners[d * 4 + 2].SetPosition(left + side, h - side - radius, 1);
        corners[d * 4 + 3] = Sprite(Image("corner-br.png"));
        corners[d * 4 + 3].SetPosition(left + w - side - radius, h - side - radius, 1);
        logos[d] = Sprite(logo_image);
        logos[d].SetPosition(screen_cx[d] - logo_image.GetWidth() / 2, screen_cy[d] - logo_image.GetHeight() + 16, 2);
        names[d] = Sprite(name_image);
        names[d].SetPosition(screen_cx[d] - name_image.GetWidth() / 2, screen_cy[d] + 44, 2);
        # The band: six segments, lit up to the boot's progress.
        for (i = 0; i < 6; i++)
          {{
            segs[d * 6 + i] = Sprite(off_image);
            segs[d * 6 + i].SetPosition(screen_cx[d] - (6 * seg_w + 5 * seg_gap) / 2 + i * (seg_w + seg_gap), (band - seg_h) / 2, 2);
          }}
        left = left + w + 64;
      }}
    show_progress();
  }}

fun show_progress ()
  {{
    for (d = 0; d < laid; d++)
      for (i = 0; i < 6; i++)
        {{
          if (i <= lit)
            segs[d * 6 + i].SetImage(seg_image[i]);
          else
            segs[d * 6 + i].SetImage(off_image);
          if (i < lit)
            segs[d * 6 + i].SetOpacity(1);
        }}
  }}
fun progress_callback (duration, progress)
  {{
    lit = Math.Int(progress * 6);
    show_progress();
  }}
Plymouth.SetBootProgressFunction (progress_callback);

time = 0;
fun refresh_callback ()
  {{
    n = count_screens();
    if (n != laid || Window.GetX(n - 1) != placed[n - 1])
      layout();
    time++;  # 50 per second
    if (lit < 6)
      for (d = 0; d < laid; d++)
        segs[d * 6 + lit].SetOpacity(0.35 + 0.65 * (Math.Cos(time / 50 * 2 * 3.14159 / 1.2) + 1) / 2);  # 1.2 s a pulse
  }}
Plymouth.SetRefreshFunction (refresh_callback);
layout();

# Messages (fsck and such): muted, centred near the laptop's bottom.
message.sprite = Sprite();
fun display_message_callback (text)
  {{
    message.image = Image.Text(text, {script_rgb(ui['fg_muted'])});
    message.sprite.SetImage(message.image);
    message.sprite.SetPosition(screen_cx[primary] - message.image.GetWidth() / 2, screen_bottom[primary] - 64, 3);
    message.sprite.SetOpacity(1);
  }}
fun hide_message_callback (text)
  {{
    message.sprite.SetOpacity(0);
  }}
Plymouth.SetDisplayMessageFunction (display_message_callback);
Plymouth.SetHideMessageFunction (hide_message_callback);

# A password request (none expected: no disk encryption), on the laptop: the lock screen's
# field, the prompt above it, one bullet per key.
field.sprite = Sprite(Image("field.png"));
field.sprite.SetOpacity(0);
lock.sprite = Sprite(Image("lock.png"));
lock.sprite.SetOpacity(0);
prompt.sprite = Sprite();
bullets.sprite = Sprite();
fun display_password_callback (text, count)
  {{
    fx = screen_cx[primary] - field_w / 2;
    fy = screen_cy[primary] + 110;
    field.sprite.SetPosition(fx, fy, 3);
    lock.sprite.SetPosition(fx + 21, fy + (field_h - lock_size) / 2, 4);
    prompt.image = Image.Text(text, {script_rgb(ui['fg_muted'])});
    prompt.sprite.SetImage(prompt.image);
    prompt.sprite.SetPosition(screen_cx[primary] - prompt.image.GetWidth() / 2, fy - prompt.image.GetHeight() - 16, 4);
    line = "";
    for (i = 0; i < count; i++)
      line = line + "• ";
    bullets.image = Image.Text(line, {script_rgb(ui['fg'])});
    bullets.sprite.SetImage(bullets.image);
    bullets.sprite.SetPosition(fx + 64, fy + (field_h - bullets.image.GetHeight()) / 2, 4);
    field.sprite.SetOpacity(1);
    lock.sprite.SetOpacity(1);
    prompt.sprite.SetOpacity(1);
    bullets.sprite.SetOpacity(1);
    names[primary].SetOpacity(0);
  }}
fun display_normal_callback ()
  {{
    field.sprite.SetOpacity(0);
    lock.sprite.SetOpacity(0);
    prompt.sprite.SetOpacity(0);
    bullets.sprite.SetOpacity(0);
    names[primary].SetOpacity(1);
  }}
Plymouth.SetDisplayPasswordFunction (display_password_callback);
Plymouth.SetDisplayNormalFunction (display_normal_callback);
""")
