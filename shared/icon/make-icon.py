# NexusEwik — Copyright (C) 2026 ratewik. GPL-3.0, see LICENSE.
# Usage: python make-icon.py [out_dir]  → NexusEwik app icons (needs Pillow).
# The mark: a near-black rounded tile with four rounded diamonds (vertical gradient
# with a bright waterline, lavender border) and small lavender dots in the corners.
# This mirrors shared/icon/make-icons.ps1 (the trusted generator used to build the
# shipped assets); tweak both if the mark changes.
import os
import sys
import math
from PIL import Image, ImageChops, ImageDraw, ImageFilter

out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
SS = 4
S = 1024 * SS
DARK_TILE = (17, 17, 19, 255)
BORDER = (229, 220, 248, 255)
RING_CORE = (74, 60, 124, 255)

DIAMONDS = ((528, 294), (309, 562), (749, 562), (528, 828))
SIDE = 257
HALF = 181            # half diagonal of the rotated square
CORNER = 70           # corner rounding of the unrotated square
BORDER_W = 22
WATER = 0.44          # waterline position within the diamond's height

DOTS = (
    (257, 155, 27, 'ring'), (176, 214, 21, 'ring'),
    (180, 300, 15, 'solid'), (293, 269, 13, 'solid'),
    (846, 728, 23, 'ring'), (974, 727, 18, 'ring'),
    (1103, 790, 16, 'solid'), (1167, 930, 26, 'ring'),
)

# vertical gradient stops (fraction of the diamond's height, RGB)
GRADIENT = (
    (0.0, (201, 188, 236)),
    (0.42, (162, 146, 212)),
    (0.455, (214, 199, 242)),
    (0.52, (104, 89, 172)),
    (0.78, (48, 39, 92)),
    (1.0, (30, 23, 58)),
)


def rounded_mask(size, box, r):
    m = Image.new('L', (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([
        box[0] * SS, box[1] * SS, box[2] * SS, box[3] * SS
    ], radius=r * SS, fill=255)
    return m


def diamond_mask(width, side, r):
    """A rotated rounded square, centred, of width × width."""
    pad = 4 * SS
    big = side + pad
    m = Image.new('L', (big, big), 0)
    ImageDraw.Draw(m).rounded_rectangle(
        (pad // 2, pad // 2, pad // 2 + side, pad // 2 + side), radius=r, fill=255)
    m = m.rotate(45, resample=Image.NEAREST, expand=True)
    return m


def vertical_gradient(w, h, stops):
    lut = []
    for i in range(h):
        t = i / max(1, h - 1)
        for (a, ca), (b, cb) in zip(stops, stops[1:]):
            if t <= b:
                u = 0 if b == a else (t - a) / (b - a)
                lut.append(tuple(round(ca[j] + (cb[j] - ca[j]) * u) for j in range(3)) + (255,))
                break
        else:
            lut.append(stops[-1][1] + (255,))
    im = Image.new('RGBA', (w, h))
    im.putdata(lut * w)
    return im


def paste_layer(base, layer, cx, cy):
    w, h = layer.size
    base.alpha_composite(layer, (round(cx * SS - w / 2), round(cy * SS - h / 2)))


def one_diamond(cx, cy):
    d_size = int(math.ceil(HALF * 2 + BORDER_W * 2 + 8 * SS))
    layer = Image.new('RGBA', (d_size, d_size), (0, 0, 0, 0))
    cxl = d_size // 2

    outer = diamond_mask(d_size, SIDE * SS, CORNER * SS)
    ow, oh = outer.size
    layer.paste(BORDER, (cxl - ow // 2, cxl - oh // 2), outer)

    inner = diamond_mask(d_size, (SIDE - 2 * BORDER_W) * SS, (CORNER - BORDER_W) * SS)
    iw, ih = inner.size
    grad = vertical_gradient(iw, ih, GRADIENT)
    layer.paste(grad, None, inner)

    # waterline: soft glow band + thin bright core
    top = cy - HALF
    wl = top + WATER * 2 * HALF
    line_y = round((wl - cxl) * SS if False else 0)
    # work in layer coords: layer centre corresponds to (cx, cy)
    wy = (wl - cy) * SS
    glow = Image.new('RGBA', (d_size, d_size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rectangle(
        (cxl - round(HALF * 0.92 * SS), cxl + wy - 9 * SS,
         cxl + round(HALF * 0.92 * SS), cxl + wy + 9 * SS),
        fill=(178, 168, 220, 24))
    layer.alpha_composite(Image.composite(glow, Image.new('RGBA', glow.size, (0, 0, 0, 0)), inner))
    core = Image.new('RGBA', (d_size, d_size), (0, 0, 0, 0))
    cd = ImageDraw.Draw(core)
    cd.line(
        (cxl - round(HALF * 0.92 * SS), cxl + wy, cxl + round(HALF * 0.92 * SS), cxl + wy),
        fill=(230, 224, 248, 70), width=round(3.5 * SS))
    layer.alpha_composite(Image.composite(core, Image.new('RGBA', core.size, (0, 0, 0, 0)), inner))
    return layer


def art():
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    bg = Image.new('RGBA', (S, S), DARK_TILE)
    im.paste(bg, (0, 0), rounded_mask(1024, (0, 0, 1024, 1024), 130))
    for cx, cy in DIAMONDS:
        paste_layer(im, one_diamond(cx, cy), cx, cy)
    for x, y, r, kind in DOTS:
        rr = r * SS
        px = (round(x * SS - rr), round(y * SS - rr), round(x * SS + rr), round(y * SS + rr))
        d = ImageDraw.Draw(im)
        d.ellipse(px, fill=BORDER)
        if kind == 'ring':
            ir = round(rr * 0.56)
            d.ellipse(
                (round(x * SS - ir), round(y * SS - ir), round(x * SS + ir), round(y * SS + ir)),
                fill=RING_CORE)
    return im


def framed(im, full):
    o = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    if full:
        o.paste(im, (0, 0), rounded_mask(1024, (0, 0, 1024, 1024), 130))
        return o.resize((1024, 1024), Image.LANCZOS)
    sh = Image.new('L', (S, S), 0)
    ImageDraw.Draw(sh).rounded_rectangle(
        (100 * SS, 112 * SS, 924 * SS, 936 * SS), radius=185 * SS, fill=110)
    o.paste((6, 4, 14, 255), (0, 0), sh.filter(ImageFilter.GaussianBlur(10 * SS)))
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    layer.paste(im.resize((round(S * 824 / 1024),) * 2, Image.LANCZOS), (100 * SS, 100 * SS))
    o.paste(layer, (0, 0), rounded_mask(1024, (100, 100, 924, 924), 185))
    return o.resize((1024, 1024), Image.LANCZOS)


os.makedirs(out, exist_ok=True)
for name in ('nexusewik', 'nexusewik-dark'):
    full, mac = framed(art(), True), framed(art(), False)
    full.save(os.path.join(out, f'{name}.png'))
    mac.save(os.path.join(out, f'{name}-mac.png'))
    full.save(os.path.join(out, f'{name}.ico'),
              sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    mac.save(os.path.join(out, f'{name}.icns'))
    for n in (16, 32, 48, 64, 128, 256, 512):
        full.resize((n, n), Image.LANCZOS).save(os.path.join(out, f'{name}-{n}.png'))
print('wrote', out)
