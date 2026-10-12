"""Spark launcher icons: preview candidates, then apply the chosen one.

    python tools/make_icons.py                 # write design/icons/* previews
    python tools/make_icons.py --apply B       # install option B into android/

Glyphs are drawn separately from the background because Android adaptive icons
need the mark alone on a transparent canvas, sized so it survives the launcher's
mask: the foreground is 108dp with only the middle 72dp guaranteed visible.

Everything is rendered at 4x and downsampled with LANCZOS, which is what keeps
the thin lime tips clean at launcher sizes.
"""

import argparse
import math
import os
import shutil

from PIL import Image, ImageDraw, ImageFont

S = 1024
SS = 4
OUT = os.path.join("design", "icons")
RES = os.path.join("android", "app", "src", "main", "res")

ACCENT = (216, 241, 78)
BG_TOP = (30, 30, 40)
BG_BOTTOM = (8, 8, 12)
CORNER = 0.225

# Adaptive-icon geometry, in dp.
ADAPTIVE_FOREGROUND_DP = 108
ADAPTIVE_SAFE_DP = 72

# The glyph is drawn smaller than the raw safe-zone ratio. The safe area is a
# 72dp *circle*, but these glyphs are wider than they are tall (the volcano spans
# ~71% horizontally), so filling 72dp width would push the corners of the mark
# outside the circle and a round launcher mask clips them.
ADAPTIVE_GLYPH_SCALE = 0.60

# density suffix -> (legacy icon px, adaptive foreground px)
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}


def _lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _bezier(p0, p1, p2, p3, steps):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        pts.append(
            (
                mt**3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t**3 * p3[0],
                mt**3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return pts


def sparkle(cx, cy, r, waist=0.14, steps=36):
    """Four-point sparkle with sharp tips.

    Straight-sided polygons read as a plus sign; the concave sides are what make
    it a spark, so each side is a cubic pulled toward the centre by `waist`.
    """
    top, right = (cx, cy - r), (cx + r, cy)
    bottom, left = (cx, cy + r), (cx - r, cy)
    w = waist * r
    return (
        [top]
        + _bezier(top, (cx + w, cy - w), (cx + w, cy - w), right, steps)
        + _bezier(right, (cx + w, cy + w), (cx + w, cy + w), bottom, steps)
        + _bezier(bottom, (cx - w, cy + w), (cx - w, cy + w), left, steps)
        + _bezier(left, (cx - w, cy - w), (cx - w, cy - w), top, steps)
    )


def draw_note(d, cx, cy, scale, color):
    head_r = 0.155 * scale
    d.ellipse((cx - head_r * 1.25, cy - head_r, cx + head_r * 0.85, cy + head_r), fill=color)
    stem_w = 0.082 * scale
    stem_top = cy - 0.60 * scale
    sx = cx + head_r * 0.55
    d.rounded_rectangle((sx, stem_top, sx + stem_w, cy), radius=stem_w / 2, fill=color)
    d.polygon(
        [
            (sx, stem_top),
            (sx + 0.32 * scale, stem_top + 0.15 * scale),
            (sx + 0.28 * scale, stem_top + 0.35 * scale),
            (sx, stem_top + 0.20 * scale),
        ],
        fill=color,
    )


# --------------------------------------------------------------------------
# Glyphs, drawn into an n x n context. No background.
# --------------------------------------------------------------------------


def glyph_a(d, n):
    d.polygon(sparkle(n * 0.5, n * 0.5, n * 0.33, 0.13), fill=ACCENT)


def glyph_b(d, n):
    d.polygon(sparkle(n * 0.38, n * 0.33, n * 0.185, 0.15), fill=ACCENT)
    draw_note(d, n * 0.52, n * 0.68, n * 0.40, ACCENT)


def glyph_c(d, n):
    heights = [0.20, 0.38, 0.58, 0.38, 0.24]
    width, gap = 0.082, 0.058
    total = len(heights) * width + (len(heights) - 1) * gap
    x = (1 - total) / 2 * n
    for h in heights:
        bar = h * n
        d.rounded_rectangle(
            (x, n / 2 - bar / 2, x + width * n, n / 2 + bar / 2),
            radius=width * n / 2,
            fill=ACCENT,
        )
        x += (width + gap) * n


def glyph_d(d, n):
    tri = [(n * 0.24, n * 0.31), (n * 0.65, n * 0.56), (n * 0.24, n * 0.81)]
    d.polygon(tri, fill=ACCENT)
    for x, y in tri:
        r = n * 0.028
        d.ellipse((x - r, y - r, x + r, y + r), fill=ACCENT)
    d.polygon(sparkle(n * 0.755, n * 0.275, n * 0.15, 0.14), fill=ACCENT)


def glyph_e(d, n):
    c = n / 2
    for r in (0.41, 0.335, 0.26):
        rr = r * n
        d.ellipse((c - rr, c - rr, c + rr, c + rr), outline=ACCENT, width=int(n * 0.022))
    d.polygon(sparkle(c, c, n * 0.155, 0.14), fill=ACCENT)


def glyph_f(d, n):
    d.polygon(sparkle(n * 0.44, n * 0.56, n * 0.27, 0.13), fill=ACCENT)
    d.polygon(sparkle(n * 0.73, n * 0.27, n * 0.115, 0.13), fill=ACCENT)


def glyph_g(d, n):
    cx, cy = n * 0.45, n * 0.74
    head_r = n * 0.12
    d.ellipse((cx - head_r * 1.3, cy - head_r, cx + head_r * 0.9, cy + head_r), fill=ACCENT)
    stem_w = n * 0.056
    sx = cx + head_r * 0.55
    stem_top = cy - n * 0.30
    d.rounded_rectangle((sx, stem_top, sx + stem_w, cy), radius=stem_w / 2, fill=ACCENT)
    d.polygon(
        sparkle(sx + stem_w * 0.5 + n * 0.10, stem_top - n * 0.02, n * 0.165, 0.14),
        fill=ACCENT,
    )


# --------------------------------------------------------------------------
# QN monogram and eruption glyphs
# --------------------------------------------------------------------------

FONT_BLACK = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "ariblk.ttf")
FONT_BOLD = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf")


def _draw_text(d, text, n, font_path, size_frac, dy=0.0, dx=0.0, tracking=0.0):
    """Draw text centred in the n x n box, with optional letter-spacing."""
    font = ImageFont.truetype(font_path, int(n * size_frac))
    if tracking and len(text) > 1:
        widths = [d.textlength(ch, font=font) for ch in text]
        gap = tracking * n
        total = sum(widths) + gap * (len(text) - 1)
        x = (n - total) / 2 + dx * n
        for ch, w in zip(text, widths):
            bbox = d.textbbox((0, 0), ch, font=font)
            d.text((x - bbox[0], (n - (bbox[3] - bbox[1])) / 2 - bbox[1] + dy * n),
                   ch, font=font, fill=ACCENT)
            x += w + gap
        return
    bbox = d.textbbox((0, 0), text, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((n - w) / 2 - bbox[0] + dx * n, (n - h) / 2 - bbox[1] + dy * n),
           text, font=font, fill=ACCENT)


def _draw_qn(d, n, size_frac=0.44, tracking=-0.01, font_path=FONT_BLACK):
    """Draws QN centred and returns metrics so accents can be placed against it."""
    font = ImageFont.truetype(font_path, int(n * size_frac))
    widths = [d.textlength(ch, font=font) for ch in "QN"]
    gap = tracking * n
    total = sum(widths) + gap
    x = (n - total) / 2
    bbox = d.textbbox((0, 0), "QN", font=font)
    h = bbox[3] - bbox[1]
    y = (n - h) / 2 - bbox[1]
    for ch, w in zip("QN", widths):
        d.text((x, y), ch, font=font, fill=ACCENT)
        x += w + gap
    return {"left": (n - total) / 2, "width": total, "top": y, "height": h}


def glyph_h(d, n):
    """QN wordmark with the note centred against it, not crammed in a corner."""
    metrics = _draw_qn(d, n, size_frac=0.40, tracking=-0.012)
    note_x = metrics["left"] + metrics["width"] + n * 0.055
    note_cy = metrics["top"] + metrics["height"] * 0.52
    draw_note(d, note_x, note_cy, n * 0.28, ACCENT)


def glyph_j(d, n):
    """QN with a spark sitting clear of the wordmark, top right."""
    metrics = _draw_qn(d, n, size_frac=0.40, tracking=-0.012)
    d.polygon(
        sparkle(
            metrics["left"] + metrics["width"] + n * 0.055,
            metrics["top"] + metrics["height"] * 0.46,
            n * 0.11,
            0.13,
        ),
        fill=ACCENT,
    )


def glyph_k(d, n):
    """QN where the N's last stem runs up into a note stem and flag."""
    metrics = _draw_qn(d, n, size_frac=0.40, font_path=FONT_BOLD)
    stem_x = metrics["left"] + metrics["width"] - n * 0.042
    stem_w = n * 0.036
    stem_top = metrics["top"] - n * 0.14
    d.rounded_rectangle(
        (stem_x, stem_top, stem_x + stem_w, metrics["top"] + metrics["height"] * 0.60),
        radius=stem_w / 2,
        fill=ACCENT,
    )
    # Flag: a broad, curved wedge so it reads as a note, not an antenna.
    d.polygon(
        [
            (stem_x, stem_top),
            (stem_x + n * 0.175, stem_top + n * 0.075),
            (stem_x + n * 0.150, stem_top + n * 0.210),
            (stem_x + n * 0.030, stem_top + n * 0.150),
            (stem_x, stem_top + n * 0.115),
        ],
        fill=ACCENT,
    )


def _volcano_body(d, n, top_y, base_y, crater_half, base_half, power=1.22):
    """A volcano silhouette: near-straight flanks with a shallow flared base
    and a notched vent. A large `power` bulges the base into a dome, which
    reads as a mushroom rather than a mountain."""
    steps = 26
    left_base, left_top = 0.5 - base_half, 0.5 - crater_half
    right_base, right_top = 0.5 + base_half, 0.5 + crater_half

    pts = []
    for i in range(steps + 1):
        t = i / steps
        pts.append(
            (
                (left_base + (left_top - left_base) * (t**power)) * n,
                (base_y + (top_y - base_y) * t) * n,
            )
        )
    # Vent: the rim dips in the middle instead of running flat across.
    pts.append((right_top * n, top_y * n))
    pts.append((0.5 * n, (top_y + 0.055) * n))
    pts.append((left_top * n, top_y * n))
    for i in range(steps, -1, -1):
        t = i / steps
        pts.append(
            (
                (right_base + (right_top - right_base) * (t**power)) * n,
                (base_y + (top_y - base_y) * t) * n,
            )
        )
    d.polygon(pts, fill=ACCENT)


def glyph_l(d, n):
    """A volcano throwing embers -- the literal reading of the name."""
    _volcano_body(d, n, top_y=0.535, base_y=0.84, crater_half=0.135, base_half=0.355)
    for cx, cy, r in [
        (0.50, 0.29, 0.078),
        (0.355, 0.225, 0.050),
        (0.645, 0.205, 0.058),
        (0.265, 0.375, 0.036),
        (0.735, 0.345, 0.042),
        (0.50, 0.115, 0.034),
    ]:
        d.polygon(sparkle(n * cx, n * cy, n * r, 0.14), fill=ACCENT)


def glyph_m(d, n):
    """An upward fan of sparks -- a spark going off, not a starfish."""
    cx, cy = n * 0.5, n * 0.80
    for angle_deg, length, half_w in [
        (90, 0.56, 0.062),
        (68, 0.50, 0.052),
        (112, 0.50, 0.052),
        (46, 0.40, 0.042),
        (134, 0.40, 0.042),
        (24, 0.29, 0.032),
        (156, 0.29, 0.032),
    ]:
        a = math.radians(angle_deg)
        tipx, tipy = cx + math.cos(a) * n * length, cy - math.sin(a) * n * length
        px, py = -math.sin(a), -math.cos(a)
        w = n * half_w * 0.45
        d.polygon(
            [(cx + px * w, cy + py * w), (tipx, tipy), (cx - px * w, cy - py * w)],
            fill=ACCENT,
        )
    # Droplets, so it reads as thrown material rather than a drawn star.
    for cx2, cy2, r in [(0.50, 0.16, 0.038), (0.33, 0.32, 0.030), (0.67, 0.30, 0.034)]:
        d.ellipse(
            (
                n * cx2 - n * r,
                n * cy2 - n * r,
                n * cx2 + n * r,
                n * cy2 + n * r,
            ),
            fill=ACCENT,
        )
    d.ellipse((cx - n * 0.085, cy - n * 0.085, cx + n * 0.085, cy + n * 0.085), fill=ACCENT)


def glyph_n(d, n):
    """A volcano whose plume resolves into a music note."""
    _volcano_body(d, n, top_y=0.60, base_y=0.87, crater_half=0.125, base_half=0.345)
    draw_note(d, n * 0.45, n * 0.33, n * 0.30, ACCENT)
    d.polygon(sparkle(n * 0.705, n * 0.265, n * 0.070, 0.14), fill=ACCENT)


GLYPHS = {
    "A": ("Sharp sparkle", glyph_a),
    "B": ("Sparkle + note", glyph_b),
    "C": ("Equalizer", glyph_c),
    "D": ("Play + spark", glyph_d),
    "E": ("Vinyl + spark", glyph_e),
    "F": ("Twin sparkle", glyph_f),
    "G": ("Note + spark", glyph_g),
    "H": ("QN + note", glyph_h),
    "J": ("QN + spark", glyph_j),
    "K": ("QN note stem", glyph_k),
    "L": ("Volcano", glyph_l),
    "M": ("Eruption burst", glyph_m),
    "N": ("Volcano + note", glyph_n),
}



# --------------------------------------------------------------------------
# Composition
# --------------------------------------------------------------------------


def background_layer(n, top=BG_TOP, bottom=BG_BOTTOM, corner=CORNER):
    grad = Image.new("RGB", (1, n))
    for y in range(n):
        grad.putpixel((0, y), _lerp(top, bottom, y / (n - 1)))
    bg = grad.resize((n, n), Image.BILINEAR)

    mask = Image.new("L", (n, n), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, n - 1, n - 1), radius=int(n * corner), fill=255
    )
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    return out


def _draw_scaled_glyph(img, key, n, glyph_scale):
    """Draws the glyph centred, optionally shrunk within the same canvas.

    Both branches below go through here: the scale was previously applied only
    on the backgrounded path, so the adaptive foreground silently ignored it and
    the mark ran into the launcher's mask.
    """
    if glyph_scale >= 1.0:
        GLYPHS[key][1](ImageDraw.Draw(img), n)
        return

    inner = max(1, int(n * glyph_scale))
    glyph = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    GLYPHS[key][1](ImageDraw.Draw(glyph), inner)
    off = int((n - inner) / 2)
    img.paste(glyph, (off, off), glyph)


def render(key, size, ss=SS, with_bg=True, glyph_scale=1.0):
    n = size * ss
    img = background_layer(n) if with_bg else Image.new("RGBA", (n, n), (0, 0, 0, 0))
    _draw_scaled_glyph(img, key, n, glyph_scale)
    return img.resize((size, size), Image.LANCZOS)


# --------------------------------------------------------------------------
# Preview mode
# --------------------------------------------------------------------------


def write_contact_sheet():
    os.makedirs(OUT, exist_ok=True)
    keys = list(GLYPHS)
    for key in keys:
        render(key, S).save(os.path.join(OUT, f"option_{key}.png"))
        print(f"wrote design/icons/option_{key}.png")

    cols = 4
    rows = math.ceil(len(keys) / cols)
    cell, pad, label_h = 300, 26, 42
    sheet = Image.new(
        "RGB",
        (cols * cell + (cols + 1) * pad, rows * (cell + label_h) + (rows + 1) * pad),
        (18, 18, 22),
    )
    sd = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 22)
        small = ImageFont.truetype("arial.ttf", 18)
    except OSError:
        font = small = ImageFont.load_default()

    for i, key in enumerate(keys):
        r, c = divmod(i, cols)
        x = pad + c * (cell + pad)
        y = pad + r * (cell + label_h + pad)
        sheet.paste(
            render(key, cell).convert("RGB").resize((cell, cell), Image.LANCZOS), (x, y)
        )
        sd.text((x, y + cell + 8), f"{key}. {GLYPHS[key][0]}", fill=(225, 225, 235), font=font)
    sheet.save(os.path.join(OUT, "contact_sheet.png"))
    print("wrote design/icons/contact_sheet.png")

    strip = Image.new("RGB", (len(keys) * 84 + 20, 120), (18, 18, 22))
    sdd = ImageDraw.Draw(strip)
    for i, key in enumerate(keys):
        x = 20 + i * 84
        strip.paste(render(key, 64).convert("RGB"), (x, 14))
        sdd.text((x + 22, 86), key, fill=(200, 200, 210), font=small)
    strip.save(os.path.join(OUT, "small_sizes.png"))
    print("wrote design/icons/small_sizes.png")


# --------------------------------------------------------------------------
# Apply mode
# --------------------------------------------------------------------------


def apply_icon(key):
    """Writes the Android launcher resources for one option.

    Produces both the legacy square icons (pre-API-26 launchers) and a proper
    adaptive icon, whose foreground is 108dp with the mark confined to the
    central 72dp so no launcher mask can clip it.
    """
    if key not in GLYPHS:
        raise SystemExit(f"unknown option {key!r}; choose from {', '.join(GLYPHS)}")

    # Full-bleed icon for legacy launchers; the adaptive foreground is drawn
    # smaller so no round mask can clip the mark.
    safe_scale = ADAPTIVE_GLYPH_SCALE

    for density, (legacy_px, fg_px) in DENSITIES.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        render(key, legacy_px).save(os.path.join(folder, "ic_launcher.png"))

        drawable = os.path.join(RES, f"drawable-{density}")
        os.makedirs(drawable, exist_ok=True)
        render(key, fg_px, with_bg=False, glyph_scale=safe_scale).save(
            os.path.join(drawable, "ic_launcher_foreground.png")
        )
        print(f"  {density}: {legacy_px}px legacy, {fg_px}px adaptive foreground")

    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
    <monochrome android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
"""
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w", encoding="utf-8") as fh:
            fh.write(adaptive)
    print(f"  wrote mipmap-anydpi-v26/ic_launcher.xml (adaptive + monochrome)")

    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    colors_path = os.path.join(values, "ic_launcher_background.xml")
    top = "#%02X%02X%02X" % BG_TOP
    with open(colors_path, "w", encoding="utf-8") as fh:
        fh.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            f'    <color name="ic_launcher_background">{top}</color>\n'
            "</resources>\n"
        )
    print(f"  wrote values/ic_launcher_background.xml ({top})")

    # Preview copy so the applied choice is easy to eyeball later.
    os.makedirs(OUT, exist_ok=True)
    render(key, 512).save(os.path.join(OUT, "applied.png"))
    print(f"applied option {key} ({GLYPHS[key][0]})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", metavar="KEY", help="install this option into android/")
    args = parser.parse_args()

    if args.apply:
        apply_icon(args.apply.upper())
    else:
        write_contact_sheet()


if __name__ == "__main__":
    main()
