"""Build the README showcase images in docs/ from the mod's own sprites.

    python3 tools/make_showcase.py      (from the repo root; needs Pillow)

Run the other generators first (sprites, costumes, entities, character art): this only
arranges what they produced, pixel-scaled with nearest-neighbour so it stays crisp.
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
GFX = ROOT / "resources/gfx"
DOCS = ROOT / "docs"
BOLD = "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"
SANS = "/usr/share/fonts/truetype/freefont/FreeSans.ttf"

NAVY = (18, 22, 40)
GOLD = (244, 204, 52)
PAPER = (232, 222, 206)
INK = (40, 30, 30)
TURF = [(40, 104, 48), (46, 116, 54)]


def font(size, bold=True):
    return ImageFont.truetype(BOLD if bold else SANS, size)


def px(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def frame(path, i=0, size=None):
    img = Image.open(path).convert("RGBA")
    s = size or img.height
    return img.crop((i * s, 0, (i + 1) * s, s))


def turf(w, h):
    img = Image.new("RGBA", (w, h), TURF[0] + (255,))
    d = ImageDraw.Draw(img)
    for i, x in enumerate(range(0, w, 64)):
        if i % 2:
            d.rectangle((x, 0, x + 63, h), fill=TURF[1] + (255,))
    for x in range(32, w, 128):
        d.line((x, 0, x, h), fill=(232, 238, 228, 255), width=3)
        for y in range(10, h, 26):                                   # hash marks
            d.line((x + 60, y, x + 68, y), fill=(232, 238, 228, 140), width=2)
    return img


def text(d, xy, s, size, fill, bold=True, shadow=True, anchor="la"):
    f = font(size, bold)
    if shadow:
        d.text((xy[0] + 3, xy[1] + 3), s, font=f, fill=(0, 0, 0, 200), anchor=anchor)
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def header(w, title, subtitle=None):
    img = Image.new("RGBA", (w, 84 if subtitle else 64), NAVY + (255,))
    d = ImageDraw.Draw(img)
    text(d, (24, 14), title, 34, GOLD)
    if subtitle:
        text(d, (26, 54), subtitle, 18, (220, 220, 230), bold=False, shadow=False)
    return img


def stack(*parts, bg=NAVY):
    w = max(p.width for p in parts)
    out = Image.new("RGBA", (w, sum(p.height for p in parts)), bg + (255,))
    y = 0
    for p in parts:
        out.alpha_composite(p, (0, y))
        y += p.height
    return out


# --- items ------------------------------------------------------------------------
def items_sheet():
    xml = (ROOT / "content/items.xml").read_text()
    entries = re.findall(r'<(passive|active|familiar|trinket) [^>]*name="([^"]+)"[^>]*gfx="([^"]+)"([^>]*)', xml)
    cards = []
    for kind, name, gfx, rest in entries:
        q = re.search(r'quality="(\d)"', rest)
        folder = "trinkets" if kind == "trinket" else "collectibles"
        icon = px(Image.open(GFX / "items" / folder / gfx).convert("RGBA").crop((0, 0, 32, 32)), 3)
        cards.append((name, kind, int(q.group(1)) if q else None, icon))
    cards.sort(key=lambda c: (-(c[2] or 0) if c[2] == 4 else 0, ["passive", "active", "familiar", "trinket"].index(c[1])))
    cols, cw, ch = 6, 200, 168
    rows = (len(cards) + cols - 1) // cols
    body = turf(cols * cw + 24, rows * ch + 24)
    d = ImageDraw.Draw(body)
    for i, (name, kind, q, icon) in enumerate(cards):
        x, y = 12 + (i % cols) * cw, 12 + (i // cols) * ch
        legend = q == 4
        d.rounded_rectangle((x + 6, y + 6, x + cw - 6, y + ch - 6), 12,
                            fill=(255, 236, 160, 255) if legend else PAPER + (255,),
                            outline=GOLD + (255,) if legend else (90, 70, 60, 255), width=4 if legend else 2)
        body.alpha_composite(icon, (x + (cw - icon.width) // 2, y + 12))
        f = font(15)
        d.text((x + cw // 2, y + 118), name, font=f, fill=INK, anchor="ma")
        tag = {"passive": "passive", "active": "active", "familiar": "familiar", "trinket": "trinket"}[kind]
        tag += f"  Q{q}" if q is not None else ""
        d.text((x + cw // 2, y + 140), tag.upper(), font=font(12, False), fill=(120, 80, 30) if legend else (90, 80, 80),
               anchor="ma")
    return stack(header(body.width, f"{len(cards)} ITEMS & TRINKETS", "Q4 legends in gold. Every one has its own mechanic."), body)


# --- characters -------------------------------------------------------------------
def characters_sheet():
    chars = [("THE QUARTERBACK", "playerportrait_quarterback.png", "Every 3rd shot is a football"),
             ("TAINTED QB", "playerportrait_quarterback_b.png", "One Ball: a boomerang bomb"),
             ("THE KICKER", "playerportrait_kicker.png", "Special Teams field goals"),
             ("TAINTED KICKER", "playerportrait_kicker_b.png", "Shanks: lobbed, exploding")]
    cw = 300
    body = turf(cw * len(chars) + 24, 330)
    d = ImageDraw.Draw(body)
    for i, (name, png, blurb) in enumerate(chars):
        x = 12 + i * cw
        d.rounded_rectangle((x + 8, 14, x + cw - 8, 316), 14, fill=PAPER + (255,), outline=(90, 70, 60, 255), width=3)
        portrait = Image.open(GFX / "ui/stage" / png).convert("RGBA")
        body.alpha_composite(px(portrait.crop(portrait.getbbox()), 2), (x + 40, 26))
        d.text((x + cw // 2, 250), name, font=font(20), fill=INK, anchor="ma")
        d.text((x + cw // 2, 280), blurb, font=font(14, False), fill=(80, 60, 60), anchor="ma")
    return stack(header(body.width, "FOUR NEW CHARACTERS", "Each with a full character-select page, co-op and death-screen art"), body)


# --- enemies + bosses ---------------------------------------------------------------
def enemies_sheet():
    foes = [("Mascot", "mascot"), ("Referee", "referee"), ("Lineman", "lineman"), ("Blitzer", "blitzer"),
            ("Punter", "punter"), ("Huddle", "huddle"), ("Cooler", "cooler"), ("Chain Gang", "chain_gang"),
            ("Sacker", "sacker", 4)]
    cw = 156
    body = turf(cw * len(foes) + 24, 230)
    d = ImageDraw.Draw(body)
    for i, foe in enumerate(foes):
        name, png = foe[0], foe[1]
        idx = foe[2] if len(foe) > 2 else 0
        sprite = px(frame(GFX / f"monsters/gridiron_{png}.png", idx), 4)
        x = 12 + i * cw
        body.alpha_composite(sprite, (x + (cw - sprite.width) // 2, 20))
        d.text((x + cw // 2, 160), name.upper(), font=font(15), fill=(250, 250, 240), anchor="ma")
    # a gold Team Captain, for flavour
    cap = frame(GFX / "monsters/gridiron_lineman.png", 3)
    tint = Image.new("RGBA", cap.size, (255, 210, 90, 0))
    capd = Image.blend(cap, Image.composite(Image.new("RGBA", cap.size, (255, 215, 90, 255)), tint, cap.split()[3]), 0.35)
    capd.putalpha(cap.split()[3])
    banner = Image.new("RGBA", (body.width, 120), (30, 34, 56, 255))
    bd = ImageDraw.Draw(banner)
    banner.alpha_composite(px(capd, 3), (24, 10))
    text(bd, (150, 26), "TEAM CAPTAINS", 26, GOLD)
    bd.text((152, 64), "15% of football enemies are gold champions: more health and a twist each", font=font(17, False),
            fill=(220, 220, 230))
    return stack(header(body.width, "10 FOOTBALL ENEMIES", "Built on Isaac's rules: giant black eyes, gore, coloured shading"),
                 body, banner)


def bosses_sheet():
    lb = px(frame(GFX / "bosses/gridiron_linebacker.png", 0, 64), 4)
    fr1 = px(frame(GFX / "bosses/gridiron_franchise.png", 2, 80), 3)
    fr2 = px(frame(GFX / "bosses/gridiron_franchise.png", 8, 80), 3)
    coach = px(frame(GFX / "monsters/gridiron_coach.png", 2, 48), 4)
    body = turf(1280, 330)
    d = ImageDraw.Draw(body)
    for img, x, name, blurb in ((lb, 30, "THE LINEBACKER", "floors 2-6"), (coach, 330, "THE COACH", "miniboss"),
                                (fr1, 600, "THE FRANCHISE", "phase 1: the route tree"),
                                (fr2, 950, "THE STADIUM", "phase 2: the wave, kiss cam, goalposts")):
        body.alpha_composite(img, (x, 280 - img.height))
        d.text((x + img.width // 2, 286), name, font=font(18), fill=GOLD, anchor="ma")
        d.text((x + img.width // 2, 308), blurb, font=font(13, False), fill=(240, 240, 230), anchor="ma")
    return stack(header(body.width, "BOSSES", "Including a two-phase final boss for floors 7-8"), body)


# --- uniforms ---------------------------------------------------------------------------
def uniforms_sheet():
    colors = ["red", "blue", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink"]
    cw = 112
    body = turf(cw * len(colors) + 24, 270)
    d = ImageDraw.Draw(body)
    for i, c in enumerate(colors):
        x = 12 + i * cw
        helmet = GFX / "items/collectibles" / ("football_helmet.png" if c == "red" else f"football_helmet_{c}.png")
        jersey = GFX / "items/collectibles" / ("team_jersey.png" if c == "blue" else f"team_jersey_{c}.png")
        body.alpha_composite(px(Image.open(helmet).convert("RGBA"), 3), (x + 8, 20))
        body.alpha_composite(px(Image.open(jersey).convert("RGBA"), 3), (x + 8, 120))
        d.text((x + cw // 2, 228), c.upper(), font=font(15), fill=(250, 250, 240), anchor="ma")
    return stack(header(body.width, "PICK YOUR TEAM COLOURS", "Helmet, jersey and pants: 11 colours each, from the settings menu"), body)


# --- field decor ------------------------------------------------------------------------------
def decor_scene():
    """Four themed rooms on a basement floor, laid out the way decor.lua dresses them."""
    anm2 = (GFX / "effects/gridiron_decor.anm2").read_text()
    sheet = Image.open(GFX / "effects/gridiron_decor.png").convert("RGBA")
    crops = {}
    for name, x, w, h, pxv, pyv in re.findall(
            r'<Animation Name="(\w+)".*?XPivot="(?:\d+)".*?XCrop="(\d+)" YCrop="0" Width="(\d+)" Height="(\d+)"()()', anm2, re.S):
        crops[name] = sheet.crop((int(x), 0, int(x) + int(w), int(h)))
    W, H = 440, 250

    def room():
        floor = Image.new("RGBA", (W, H), (82, 62, 52, 255))
        d = ImageDraw.Draw(floor)
        for x in range(0, W, 26):
            for y in range(0, H, 26):
                shade = 6 if (x // 26 + y // 26) % 2 else 0
                d.rectangle((x, y, x + 25, y + 25), fill=(82 - shade, 62 - shade, 52 - shade, 255))
        return floor

    def put(floor, name, cx, cy, flip=False, base=False):
        img = crops[name].transpose(Image.FLIP_LEFT_RIGHT) if flip else crops[name]
        y = cy - img.height if base else cy - img.height // 2
        floor.alpha_composite(img, (cx - img.width // 2, y))

    field = room()
    put(field, "EndStripes", 34, 125)
    put(field, "EndStripes", W - 34, 125, True)
    for x, n in ((120, "Num10"), (220, "Num20"), (320, "Num10")):
        put(field, "Yardline", x, 125)
        put(field, n, x, 22)
        put(field, n, x, H - 22)
    put(field, "Goalpost", 18, 150, base=True)
    put(field, "Goalpost", W - 18, 150, True, base=True)
    put(field, "TurfSmall", 260, 190)
    lockers = room()
    for i, x in enumerate(range(24, 400, 21)):
        if 190 < x < 250:
            continue
        put(lockers, "LockerOpen" if i in (3, 11) else "Locker", x, 46, base=True)
    put(lockers, "Whiteboard", 220, 40, base=True)
    put(lockers, "Bench", 220, 92, base=True)
    put(lockers, "Drain", 220, 160)
    for x, y in ((180, 150), (260, 175), (220, 195)):
        put(lockers, "Puddle", x, y)
    for name, x, y in (("Towel", 90, 160), ("JerseyFloor", 330, 140), ("Helmet", 360, 200), ("Tape", 120, 210)):
        put(lockers, name, x, y)
    put(lockers, "Trash", 410, 240, base=True)
    drills = room()
    for i in range(6):
        put(drills, "Cone", 130 + i * 36, 70, base=True)
    put(drills, "Ladder", 60, 125)
    for row in range(2):
        for col in range(3):
            put(drills, "Tire", 230 + col * 26 + row * 13, 160 + row * 18, base=True)
    put(drills, "BallBag", 380, 120, base=True)
    put(drills, "Sled", 380, 220, base=True)
    turf = room()
    for name, x, y in (("Turf", 120, 90), ("Turf", 300, 170), ("TurfSmall", 330, 60), ("TurfSmall", 90, 200)):
        put(turf, name, x, y)
    put(turf, "Yardline", 210, 125)
    put(turf, "Pylon", 160, 150, base=True)
    put(turf, "Cups", 360, 210)

    body = Image.new("RGBA", (W * 2 * 2 + 36, (H * 2 + 40) * 2 + 12), NAVY + (255,))
    bd = ImageDraw.Draw(body)
    for i, (img, label) in enumerate(((field, "GAME FIELD"), (lockers, "LOCKER ROOM"), (drills, "PRACTICE FIELD"),
                                      (turf, "TURF FIELD"))):
        x, y = 12 + (i % 2) * (W * 2 + 12), 12 + (i // 2) * (H * 2 + 40)
        body.alpha_composite(px(img, 2), (x, y + 30))
        bd.text((x + 4, y + 4), label, font=font(20), fill=GOLD)
    return stack(header(body.width, "FOOTBALL IN THE BASEMENT",
                        "About one room in eight is dressed: game fields, locker rooms, practice fields, torn turf, sidelines"), body)


# --- banner -------------------------------------------------------------------------------
def banner():
    w, h = 1280, 420
    img = turf(w, h)
    shade = Image.new("RGBA", (w, h), (10, 14, 30, 120))
    img.alpha_composite(shade)
    d = ImageDraw.Draw(img)
    helmet = px(Image.open(GFX / "items/collectibles/football_helmet.png").convert("RGBA"), 7)
    img.alpha_composite(helmet, (50, 90))
    fr = px(frame(GFX / "bosses/gridiron_franchise.png", 2, 80), 4)
    img.alpha_composite(fr, (w - fr.width - 30, h - fr.height - 6))
    qb = Image.open(GFX / "ui/stage/playerportrait_quarterback.png").convert("RGBA")
    kk = Image.open(GFX / "ui/stage/playerportrait_kicker.png").convert("RGBA")
    img.alpha_composite(px(qb.crop(qb.getbbox()), 2), (300, 220))
    img.alpha_composite(px(kk.crop(kk.getbbox()), 2), (470, 230))
    ball = Image.open(GFX / "items/collectibles/pigskin.png").convert("RGBA")
    img.alpha_composite(px(ball, 4), (660, 290))
    title = "GRIDIRON"
    f = font(132)
    d.text((300 + 6, 26 + 6), title, font=f, fill=(0, 0, 0, 220))
    d.text((300, 26), title, font=f, fill=GOLD)
    text(d, (304, 166), "American football for The Binding of Isaac: Repentance+", 26, (245, 245, 240))
    return img


def main():
    DOCS.mkdir(exist_ok=True)
    out = {
        "banner.png": banner(),
        "items.png": items_sheet(),
        "characters.png": characters_sheet(),
        "enemies.png": enemies_sheet(),
        "bosses.png": bosses_sheet(),
        "uniforms.png": uniforms_sheet(),
        "decor.png": decor_scene(),
    }
    for name, img in out.items():
        img.convert("RGB").save(DOCS / name, optimize=True)
        print(f"docs/{name}  {img.size}")


if __name__ == "__main__":
    main()
