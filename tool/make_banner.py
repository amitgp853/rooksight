# Copyright (C) 2026 Amit Gupta
# SPDX-License-Identifier: GPL-3.0-or-later

"""Builds the README banner (design/banner.png) from the app screenshots.

Usage: python3 tool/make_banner.py   (needs Pillow)
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "design" / "screenshots"
FONTS = ROOT / "assets" / "google_fonts"
OUT = ROOT / "design" / "banner.png"

# Night Study tokens (design/design-spec.md).
BG = "#0E1217"
BG_RAISED = "#151B22"
BORDER = "#2A3441"
TEXT = "#E9EDF2"
TEXT_2 = "#A3AFBD"
FOCUS = "#86A8FF"
BRASS = "#E3B25C"

W, H = 2560, 1280
PHONE_H = 940
SCREENS = ["home.png", "scan-check.png", "review-moments.png", "coach.png"]
# Vertical stagger for each phone, so the row reads as a fan.
STAGGER = [190, 110, 210, 130]


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, *img.size), radius, fill=255)
    img.putalpha(mask)
    return img


def phone(path):
    shot = Image.open(path).convert("RGBA")
    w = round(shot.width * PHONE_H / shot.height)
    shot = rounded(shot.resize((w, PHONE_H), Image.LANCZOS), 56)
    # Thin bezel in the border colour.
    frame = Image.new("RGBA", (w + 8, PHONE_H + 8), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle(
        (0, 0, w + 7, PHONE_H + 7), 60, fill=BORDER
    )
    frame.alpha_composite(shot, (4, 4))
    return frame


def shadow(size, radius=60, blur=40):
    pad = blur * 2
    sh = Image.new("RGBA", (size[0] + pad * 2, size[1] + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        (pad, pad, pad + size[0], pad + size[1]), radius, fill=(0, 0, 0, 170)
    )
    return sh.filter(ImageFilter.GaussianBlur(blur)), pad


def main():
    canvas = Image.new("RGBA", (W, H), BG)

    # Soft focus-blue glow behind the phones.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((1100, 150, 2500, 1150), fill=(134, 168, 255, 50))
    canvas.alpha_composite(glow.filter(ImageFilter.GaussianBlur(160)))

    # Left: logo, name, tagline, feature chips.
    x = 140
    icon = Image.open(ROOT / "assets" / "icon" / "app_icon_1024.png").convert("RGBA")
    icon = rounded(icon.resize((168, 168), Image.LANCZOS), 40)
    canvas.alpha_composite(icon, (x, 250))

    d = ImageDraw.Draw(canvas)
    d.text((x, 460), "Rooksight", font=font("Sora-SemiBold.ttf", 132), fill=TEXT)
    d.text(
        (x, 640),
        "An AI chess coach\nyou can trust: every move\nis verified by Stockfish.",
        font=font("InstrumentSans-Medium.ttf", 52),
        fill=TEXT_2,
        spacing=14,
    )

    chip_font = font("InstrumentSans-SemiBold.ttf", 36)
    cy = 880
    cx = x
    for i, label in enumerate(
        ["Play Stockfish", "Review", "AI Coach", "Scan a board", "Stats"]
    ):
        tw = d.textlength(label, font=chip_font)
        cw = int(tw) + 56
        if cx + cw > 820:
            cx, cy = x, cy + 90
        color = BRASS if label == "AI Coach" else FOCUS
        d.rounded_rectangle((cx, cy, cx + cw, cy + 68), 34, fill=BG_RAISED, outline=BORDER, width=2)
        d.text((cx + 28, cy + 13), label, font=chip_font, fill=color)
        cx += cw + 18

    d.text(
        (x, 1100),
        "Flutter · Android & iOS · no login",
        font=font("JetBrainsMono-Medium.ttf", 30),
        fill="#7C8898",
    )

    # Right: four overlapping phones.
    phones = [phone(SHOTS / name) for name in SCREENS]
    step = 380
    px0 = W - 120 - phones[0].width - step * (len(phones) - 1)
    for i, ph in enumerate(phones):
        px, py = px0 + i * step, STAGGER[i]
        sh, pad = shadow(ph.size)
        canvas.alpha_composite(sh, (px - pad + 10, py - pad + 24))
        canvas.alpha_composite(ph, (px, py))

    canvas.convert("RGB").save(OUT, optimize=True)
    print(f"Wrote {OUT.relative_to(ROOT)} ({W}x{H})")


if __name__ == "__main__":
    main()
