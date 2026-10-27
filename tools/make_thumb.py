"""Workshop thumbnail (thumb.png, 512x512) built from the mod's own sprites.

    python3 tools/make_thumb.py      (from the repo root; needs Pillow)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
GFX = ROOT / "resources/gfx"
FONT = "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"


def sprite(rel, scale, crop=None):
    img = Image.open(GFX / rel).convert("RGBA")
    if crop:
        img = img.crop(crop)
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def main():
    W = 512
    img = Image.new("RGBA", (W, W), (44, 110, 52, 255))
    d = ImageDraw.Draw(img)
    for i, y in enumerate(range(0, W, 32)):                 # mowed stripes + yard lines
        if i % 2:
            d.rectangle((0, y, W, y + 31), fill=(50, 122, 58, 255))
    for x in range(32, W, 64):
        d.line((x, 0, x, W), fill=(235, 240, 230, 255), width=3)
    d.rectangle((0, 0, W, 120), fill=(20, 24, 40, 235))
    d.rectangle((0, W - 120, W, W), fill=(20, 24, 40, 235))

    f = ImageFont.truetype(FONT, 76)
    title = "GRIDIRON"
    tw = d.textlength(title, font=f)
    d.text(((W - tw) / 2 + 4, 22), title, font=f, fill=(0, 0, 0, 255))
    d.text(((W - tw) / 2, 18), title, font=f, fill=(244, 204, 52, 255))
    f2 = ImageFont.truetype(FONT, 26)
    sub = "football gear for Isaac"
    d.text(((W - d.textlength(sub, font=f2)) / 2, W - 82), sub, font=f2, fill=(240, 240, 240, 255))

    img.alpha_composite(sprite("items/collectibles/football_helmet.png", 7), (32, 104))
    img.alpha_composite(sprite("bosses/gridiron_linebacker.png", 3, (0, 0, 64, 64)), (300, 150))
    img.alpha_composite(sprite("items/collectibles/pigskin.png", 4), (300, 330))
    img.alpha_composite(sprite("items/collectibles/team_jersey.png", 3), (40, 320))
    img.alpha_composite(sprite("familiars/gridiron_cheerleader.png", 3, (0, 0, 32, 32)), (150, 312))
    img.convert("RGB").save(ROOT / "thumb.png")
    print("thumb.png written")


if __name__ == "__main__":
    main()
