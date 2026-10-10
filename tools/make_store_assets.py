"""Builds the Play Store graphics from the rendered screens and the game art.

Dev-only helper (Python 3 + Pillow). It writes into store/assets/:
  screens/*.png        1080x1920 RGB, from the PNGs of tools/render_store_shots.gd
  icon_512.png         512x512, from icon.svg rendered by Godot as icon_raw.png
  feature_1024x500.png 1024x500 feature graphic

Usage, from the repo root:
    python tools/make_store_assets.py <folder with the rendered PNGs> <icon_raw.png>
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "store" / "assets"
FONT = REPO / "assets" / "fonts" / "fredoka" / "Fredoka.ttf"

SKY = (96, 204, 244)
MINT = (184, 238, 224)
INK = (24, 43, 88)
BLUE = (37, 107, 227)
PINK = (236, 56, 115)


def screens(folder: Path) -> None:
    target = OUT / "screens"
    target.mkdir(parents=True, exist_ok=True)
    for old in target.glob("*.png"):
        old.unlink()
    for path in sorted(folder.glob("*.png")):
        image = Image.open(path).convert("RGB")
        if image.size != (1080, 1920):
            image = image.resize((1080, 1920), Image.LANCZOS)
        image.save(target / path.name, optimize=True)
        print("screen", path.name, image.size)


def icon(raw: Path) -> None:
    image = Image.open(raw).convert("RGBA").resize((512, 512), Image.LANCZOS)
    image.save(OUT / "icon_512.png", optimize=True)
    print("icon", image.size)


def vertical_gradient(size, top, bottom) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        colour = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        for x in range(width):
            pixels[x, y] = colour
    return image


def polaroid(picture: Image.Image, side: int, angle: float) -> Image.Image:
    """A square picture with a white border and a soft shadow, rotated."""
    border = max(side // 24, 6)
    photo = picture.convert("RGB").resize((side, side), Image.LANCZOS)
    card = Image.new("RGBA", (side + 2 * border, side + 2 * border), (255, 255, 255, 255))
    mask = Image.new("L", card.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, card.width - 1, card.height - 1), radius=border * 2, fill=255)
    card.paste(photo, (border, border))
    card.putalpha(mask)

    pad = 40
    canvas = Image.new("RGBA", (card.width + 2 * pad, card.height + 2 * pad), (0, 0, 0, 0))
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 110), (pad + 6, pad + 12), mask)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))
    canvas.alpha_composite(card, (pad, pad))
    return canvas.rotate(angle, resample=Image.BICUBIC, expand=True)


def scene_crop(name: str) -> Image.Image:
    image = Image.open(REPO / "assets" / "scenarios" / f"{name}.png").convert("RGB")
    side = min(image.size)
    left = (image.width - side) // 2
    top = int(image.height * 0.12)
    return image.crop((left, top, left + side, top + side))


def outlined_text(draw: ImageDraw.ImageDraw, position, text, font, fill) -> None:
    draw.text(position, text, font=font, fill=fill, stroke_width=9, stroke_fill=(255, 255, 255))


def feature_graphic() -> None:
    width, height = 1024, 500
    canvas = vertical_gradient((width, height), SKY, MINT).convert("RGBA")

    # Soft circles, like the backdrop of the game.
    circles = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(circles)
    for cx, cy, radius in [(90, 60, 110), (520, 470, 130), (960, 40, 90), (330, 250, 70)]:
        draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=(255, 255, 255, 60))
    canvas.alpha_composite(circles)

    # Three tilted pictures on the right.
    for name, side, angle, position in [
        ("space_1", 250, 9, (700, 120)),
        ("city_1", 270, -7, (590, 20)),
        ("beach_1", 300, 4, (640, 150)),
    ]:
        card = polaroid(scene_crop(name), side, angle)
        canvas.alpha_composite(card, position)

    font_big = ImageFont.truetype(str(FONT), 112)
    font_small = ImageFont.truetype(str(FONT), 42)
    # Fredoka's axes are [weight, width]: bold, normal width.
    font_big.set_variation_by_axes([700, 100])
    font_small.set_variation_by_axes([600, 100])
    text = ImageDraw.Draw(canvas)
    outlined_text(text, (44, 60), "Ojos", font_big, BLUE)
    outlined_text(text, (44, 172), "Curiosos", font_big, PINK)
    text.text((52, 330), "Encuentra objetos escondidos", font=font_small, fill=INK)
    text.text((52, 382), "¡Solo o por wifi!", font=font_small, fill=INK)

    canvas.convert("RGB").save(OUT / "feature_1024x500.png", optimize=True)
    print("feature", canvas.size)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    screens(Path(sys.argv[1]))
    icon(Path(sys.argv[2]))
    feature_graphic()


if __name__ == "__main__":
    main()
