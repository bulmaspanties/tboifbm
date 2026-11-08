"""Animated Workshop / GitHub preview: docs/preview.gif.

Four short scenes on the turf, all drawn from the mod's own sprites: the title, the
six characters, the bosses (animated from their sheets) and the item pile.

Usage (from the repo root):   python3 tools/make_gif.py
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw

from make_showcase import GFX, GOLD, frame, font, px, text, turf

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/preview.gif"
W, H = 640, 360
FPS_MS = 100
SCENE = 20                         # frames per scene


def base():
    img = turf(W, H)
    img.alpha_composite(Image.new("RGBA", (W, H), (10, 14, 30, 90)))
    return img


def ball(img, t, y):
    """A spiralling football flying left to right across the scene."""
    b = Image.open(GFX / "items/collectibles/pigskin.png").convert("RGBA")
    b = px(b.crop(b.getbbox()), 2).rotate(-t * 40, resample=Image.NEAREST, expand=True)
    x = int(-40 + (W + 80) * t / SCENE)
    img.alpha_composite(b, (x, int(y - math.sin(t / SCENE * math.pi) * 60)))


def title_scene(t):
    img = base()
    d = ImageDraw.Draw(img)
    helmet = px(Image.open(GFX / "items/collectibles/football_helmet.png").convert("RGBA"), 5)
    img.alpha_composite(helmet, (W // 2 - helmet.width // 2, 40 + int(math.sin(t * 0.8) * 6)))
    text(d, (W // 2, 210), "GRIDIRON", 76, GOLD, anchor="ma")
    text(d, (W // 2, 296), "American football for Isaac: Repentance+", 22, (245, 245, 240), anchor="ma")
    ball(img, t, 160)
    return img


def characters_scene(t):
    img = base()
    d = ImageDraw.Draw(img)
    names = ["quarterback", "quarterback_b", "kicker", "kicker_b", "coach", "coach_b"]
    for i, n in enumerate(names):
        p = Image.open(GFX / f"ui/stage/playerportrait_{n}.png").convert("RGBA")
        p = p.crop(p.getbbox())
        shown = min(1.0, max(0.0, (t - i * 1.2) / 2))                 # each one slides up in turn
        x = 20 + i * 102
        y = int(110 + (1 - shown) * 260)
        img.alpha_composite(p, (x + 50 - p.width // 2, y))
    text(d, (W // 2, 24), "6 NEW CHARACTERS", 40, GOLD, anchor="ma")
    text(d, (W // 2, 318), "Quarterback, Kicker, Coach + tainted versions", 20, (245, 245, 240), anchor="ma")
    return img


def bosses_scene(t):
    img = base()
    d = ImageDraw.Draw(img)
    lb = px(frame(GFX / "bosses/gridiron_linebacker.png", t // 3 % 2, 64), 3)
    mb = px(frame(GFX / "bosses/gridiron_mascot_boss.png", [0, 1, 2, 3][t // 3 % 4], 64), 3)
    fr = px(frame(GFX / "bosses/gridiron_franchise.png", 2 if t < SCENE // 2 else 8, 80), 3)
    for sprite, x in ((lb, 20), (mb, 220), (fr, 400)):
        img.alpha_composite(sprite, (x, 330 - sprite.height))
    text(d, (W // 2, 20), "3 BOSSES + 10 FOOTBALL ENEMIES", 32, GOLD, anchor="ma")
    return img


def items_scene(t):
    img = base()
    d = ImageDraw.Draw(img)
    pngs = sorted((GFX / "items/collectibles").glob("*.png"))
    colours = ("red", "blue", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink")
    pngs = [p for p in pngs if p.stem.rsplit("_", 1)[-1] not in colours][:24]
    for i, p in enumerate(pngs):
        if i > t * 2:
            break
        icon = px(Image.open(p).convert("RGBA"), 2)
        col, row = i % 8, i // 8
        img.alpha_composite(icon, (24 + col * 76, 80 + row * 80 + int(math.sin(t * 0.7 + i) * 3)))
    text(d, (W // 2, 20), "GEAR UP: 27 ITEMS", 38, GOLD, anchor="ma")
    text(d, (W // 2, 326), "Suit up, tackle, kick field goals, go All-Pro", 20, (245, 245, 240), anchor="ma")
    return img


def main():
    frames = []
    for scene in (title_scene, characters_scene, bosses_scene, items_scene):
        frames += [scene(t).convert("RGB") for t in range(SCENE)]
    pal = [f.quantize(colors=128, method=Image.MEDIANCUT, dither=Image.NONE) for f in frames]
    pal[0].save(OUT, save_all=True, append_images=pal[1:], duration=FPS_MS, loop=0, optimize=True)
    print(f"{OUT.relative_to(ROOT)}  {len(frames)} frames, {OUT.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
