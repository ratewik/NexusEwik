# NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
# Usage: python make-tray.py  → tray / menu bar glyphs, drawn from the mark: the brand
# lattice of four small solid diamonds, one colour on transparency. White and black for
# the Windows taskbar (dark/light), a black template for the macOS menu bar (macOS tints
# it), white for Linux panels. Needs Pillow. This mirrors shared/icon/make-icons.ps1.
import os
import math
from PIL import Image, ImageDraw

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..', '..')

SS = 10          # supersampling per glyph pixel
GAP = 0.36       # diamond extent as a fraction of the glyph box
RADIUS = 0.18    # corner rounding of each diamond's underlying square

POSITIONS = ((0.5, 0.26), (0.26, 0.5), (0.74, 0.5), (0.5, 0.74))


def diamond(color, alpha_mask, size, cx, cy, width, radius):
    """Fills one rotated rounded square into alpha_mask (a PIL L image)."""
    side = width / math.sqrt(2) * size
    pad = 4
    m = Image.new('L', (int(side) + pad, int(side) + pad), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (pad // 2, pad // 2, pad // 2 + int(side), pad // 2 + int(side)),
        radius=max(1, round(radius * side)), fill=255)
    m = m.rotate(45, resample=Image.NEAREST, expand=True)
    w, h = m.size
    layer = Image.new('L', alpha_mask.size, 0)
    paint = Image.new('L', layer.size, 255)
    layer.paste(paint, (round(cx * size - w / 2), round(cy * size - h / 2)), m)
    alpha_mask.paste(255, (0, 0), layer)


def glyph(px, color):
    size = px * SS
    mask = Image.new('L', (size, size), 0)
    width = GAP * size
    for cx, cy in POSITIONS:
        diamond(color, mask, size, cx * size, cy * size, width, RADIUS)
    mask = mask.resize((px, px), Image.LANCZOS)
    out = Image.new('RGBA', (px, px), color + (0,))
    out.putalpha(mask)
    return out


def save(img, *parts):
    p = os.path.join(*parts)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p)


WHITE, BLACK = (255, 255, 255), (0, 0, 0)
win = os.path.join(root, 'windows', 'assets')
lin = os.path.join(root, 'linux', 'assets')
# Windows taskbar: 16 px and 32 px (@2x); white on a dark taskbar, black on a light one.
for base, color in (('tray-white', WHITE), ('tray-black', BLACK), ('tray', WHITE)):
    save(glyph(16, color), win, base + '.png')
    save(glyph(32, color), win, base + '@2x.png')
# Linux panels (mostly dark).
save(glyph(16, WHITE), lin, 'tray.png')
save(glyph(32, WHITE), lin, 'tray@2x.png')
# macOS menu bar template, 18 pt and @2x (for the Mac app: mac/assets/trayTemplate*.png).
save(glyph(18, BLACK), here, 'trayTemplate.png')
save(glyph(36, BLACK), here, 'trayTemplate@2x.png')
print('done')
