"""Generate placeholder 32x32 pixel-art item sprites for Gridiron.

Usage: python3 tools/make_sprites.py   (run from the repo root)
Requires Pillow. Replace the output PNGs with hand-drawn art whenever you like.
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
COLL = ROOT / "resources/gfx/items/collectibles"
TRINK = ROOT / "resources/gfx/items/trinkets"

OUTLINE = (20, 12, 12, 255)
SIZE = 32


def canvas():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def outlined(img):
    """Add a 1px dark outline around all opaque pixels (Isaac item style)."""
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < SIZE and 0 <= ny < SIZE and src[nx, ny][3]:
                    dst[x, y] = OUTLINE
                    break
    return out


def helmet():
    img, d = canvas()
    shell, shade, stripe = (200, 30, 40, 255), (140, 18, 28, 255), (245, 245, 245, 255)
    d.ellipse((4, 5, 25, 25), fill=shell)
    d.rectangle((4, 16, 14, 25), fill=shell)
    d.ellipse((6, 18, 14, 25), fill=shade)          # ear hole shadow
    d.ellipse((8, 20, 11, 23), fill=(60, 10, 14, 255))
    d.rectangle((13, 5, 15, 25), fill=stripe)        # center stripe
    d.rectangle((14, 5, 14, 25), fill=(200, 200, 210, 255))
    # facemask bars
    bar = (190, 190, 200, 255)
    d.line((22, 14, 29, 14), fill=bar, width=2)
    d.line((22, 19, 29, 19), fill=bar, width=2)
    d.line((22, 24, 28, 24), fill=bar, width=2)
    d.line((28, 13, 28, 25), fill=bar, width=2)
    d.line((22, 12, 22, 26), fill=bar, width=1)
    return outlined(img)


def shoulder_pads():
    img, d = canvas()
    pad, shade, jersey = (230, 230, 225, 255), (170, 170, 165, 255), (30, 60, 160, 255)
    d.rectangle((9, 14, 22, 29), fill=jersey)         # jersey body
    d.ellipse((2, 8, 15, 20), fill=pad)               # left pad
    d.ellipse((16, 8, 29, 20), fill=pad)              # right pad
    d.arc((2, 8, 15, 20), 20, 160, fill=shade, width=2)
    d.arc((16, 8, 29, 20), 20, 160, fill=shade, width=2)
    d.rectangle((13, 9, 18, 13), fill=(80, 50, 40, 255))  # neck hole
    d.rectangle((9, 24, 22, 25), fill=(240, 240, 240, 255))
    return outlined(img)


def team_jersey():
    img, d = canvas()
    body, trim, num = (30, 60, 160, 255), (240, 200, 40, 255), (245, 245, 245, 255)
    d.polygon([(8, 5), (13, 4), (18, 4), (23, 5), (30, 11), (26, 16), (23, 13),
               (23, 29), (8, 29), (8, 13), (5, 16), (1, 11)], fill=body)
    d.rectangle((13, 4, 18, 6), fill=trim)
    d.rectangle((1, 11, 3, 13), fill=trim)
    d.rectangle((28, 11, 30, 13), fill=trim)
    # a chunky "8"
    d.rectangle((12, 11, 19, 25), fill=num)
    d.rectangle((14, 13, 17, 16), fill=body)
    d.rectangle((14, 20, 17, 23), fill=body)
    return outlined(img)


def cleats():
    img, d = canvas()
    shoe, sole, lace = (25, 25, 30, 255), (235, 235, 235, 255), (245, 245, 245, 255)
    d.polygon([(4, 10), (12, 10), (14, 16), (27, 19), (29, 23), (4, 23)], fill=shoe)
    d.rectangle((4, 23, 29, 25), fill=sole)
    for x in (6, 11, 18, 25):                         # studs
        d.rectangle((x, 26, x + 2, 28), fill=sole)
    for y in (12, 14, 16):
        d.line((9, y, 15, y + 2), fill=lace)
    d.line((18, 20, 26, 21), fill=(200, 30, 40, 255), width=2)  # swoosh-ish stripe
    return outlined(img)


def eye_black():
    img, d = canvas()
    stick, cap, black = (230, 230, 230, 255), (40, 40, 40, 255), (10, 10, 10, 255)
    # grease stick
    d.rectangle((5, 6, 12, 26), fill=stick)
    d.rectangle((5, 6, 12, 10), fill=cap)
    d.rectangle((6, 13, 11, 18), fill=(200, 30, 40, 255))
    # two smears
    d.rounded_rectangle((16, 9, 28, 14), 2, fill=black)
    d.rounded_rectangle((16, 19, 28, 24), 2, fill=black)
    return outlined(img)


def padded_pants():
    img, d = canvas()
    pants, pad, stripe = (240, 240, 235, 255), (200, 200, 190, 255), (30, 60, 160, 255)
    d.rectangle((7, 5, 24, 9), fill=pants)            # waist
    d.polygon([(7, 9), (16, 9), (15, 27), (8, 27)], fill=pants)
    d.polygon([(16, 9), (24, 9), (23, 27), (17, 27)], fill=pants)
    d.rectangle((9, 13, 13, 18), fill=pad)            # thigh pads
    d.rectangle((18, 13, 22, 18), fill=pad)
    d.line((7, 9, 8, 27), fill=stripe, width=2)
    d.line((24, 9, 23, 27), fill=stripe, width=2)
    d.rectangle((7, 5, 24, 6), fill=(120, 80, 50, 255))  # belt
    return outlined(img)


def main():
    COLL.mkdir(parents=True, exist_ok=True)
    TRINK.mkdir(parents=True, exist_ok=True)
    helmet().save(COLL / "football_helmet.png")
    shoulder_pads().save(COLL / "shoulder_pads.png")
    team_jersey().save(COLL / "team_jersey.png")
    cleats().save(COLL / "football_cleats.png")
    eye_black().save(COLL / "eye_black.png")
    padded_pants().save(TRINK / "padded_pants.png")
    print("sprites written")


if __name__ == "__main__":
    main()
