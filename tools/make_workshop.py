"""Steam Workshop screenshots: 1920x1080 cards in docs/workshop/, built from the mod's own sprites.

    python3 tools/make_workshop.py      (from the repo root; run the sprite generators first)

Everything shown is real mod art, pixel-scaled with nearest-neighbour: item icons, character
portraits, enemy and boss sheets, and the Quarterback assembled from his character sheet plus
the actual costume sheets the game layers on him (helmet, eye black, jersey and pads, pants and
cleats), exactly as they stack in a run.
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw

from make_showcase import GFX, GOLD, INK, NAVY, PAPER, font, frame, px, turf

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs/workshop"
W, H = 1920, 1080
WHITE = (246, 246, 240)
SOFT = (214, 218, 230)
COSTUMES = GFX / "characters/costumes"
COLORS = ["red", "blue", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink"]
DEFAULTS = {"helmet": "red", "jersey": "blue", "pants": "white"}   # un-suffixed costume files


# --- frame ---------------------------------------------------------------------------------
def shadow_text(d, xy, s, size, fill, bold=True, anchor="la", offset=4):
    f = font(size, bold)
    d.text((xy[0] + offset, xy[1] + offset), s, font=f, fill=(0, 0, 0, 200), anchor=anchor)
    d.text(xy, s, font=f, fill=fill, anchor=anchor)


def card(title, subtitle):
    """Turf field, a navy title band with a gold rule, and a slim footer."""
    img = turf(W, H)
    img.alpha_composite(Image.new("RGBA", (W, H), (8, 12, 26, 80)))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, W, 176), fill=NAVY + (245,))
    d.rectangle((0, 176, W, 182), fill=GOLD + (255,))
    shadow_text(d, (72, 26), title, 78, GOLD)
    d.text((76, 120), subtitle, font=font(32, False), fill=SOFT)
    d.rectangle((0, H - 52, W, H), fill=NAVY + (235,))
    d.text((72, H - 26), "GRIDIRON", font=font(24), fill=GOLD, anchor="lm")
    d.text((W - 72, H - 26), "American football for The Binding of Isaac: Repentance+   ·   REPENTOGON not required",
           font=font(22, False), fill=SOFT, anchor="rm")
    return img, d


def paste_center(img, sprite, cx, bottom):
    img.alpha_composite(sprite, (int(cx - sprite.width / 2), int(bottom - sprite.height)))


def wrap(d, text, size, width, bold=False):
    """Greedy word wrap to a pixel width."""
    f = font(size, bold)
    lines, line = [], ""
    for word in text.split():
        trial = (line + " " + word).strip()
        if d.textlength(trial, font=f) <= width:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def write_lines(d, xy, lines, size, fill, bold=False, gap=1.28, anchor="la"):
    x, y = xy
    for line in lines:
        d.text((x, y), line, font=font(size, bold), fill=fill, anchor=anchor)
        y += int(size * gap)
    return y


def icon(path, scale):
    im = Image.open(path).convert("RGBA").crop((0, 0, 32, 32))
    return px(im, scale)


def item_icon(name, scale=3):
    return icon(GFX / "items/collectibles" / name, scale)


def suffix(kind, color):
    return "" if color == DEFAULTS[kind] else "_" + color


def quarterback(helmet="red", jersey="blue", pants="white", scale=5):
    """The Quarterback as the game draws him: his sheet's head and body, then the costume
    layers in the order the game stacks them (cleats/pants, jersey+pads; eye black, helmet)."""
    sheet = Image.open(COSTUMES / "character_quarterback.png").convert("RGBA")
    head = sheet.crop((0, 0, 32, 32))
    body = sheet.crop((0, 32, 32, 64))

    def layer(img, name, crop):
        img.alpha_composite(Image.open(COSTUMES / f"{name}.png").convert("RGBA").crop(crop))

    layer(body, "gridiron_legs_pantscleats" + suffix("pants", pants), (0, 64, 32, 96))
    layer(body, "gridiron_torso_jerseypads" + suffix("jersey", jersey), (0, 64, 32, 96))
    layer(head, "gridiron_eyeblack", (0, 0, 32, 32))
    layer(head, "gridiron_helmet" + suffix("helmet", helmet), (0, 0, 32, 32))
    fig = Image.new("RGBA", (40, 44), (0, 0, 0, 0))
    fig.alpha_composite(body, (4, 10))
    fig.alpha_composite(head, (4, 0))
    fig = fig.crop(fig.getbbox())
    return px(fig, scale)


def floor_shadow(img, cx, y, w):
    sh = Image.new("RGBA", (w, w // 4), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse((0, 0, w - 1, w // 4 - 1), fill=(0, 0, 0, 90))
    img.alpha_composite(sh, (int(cx - w / 2), int(y - w / 8)))


# --- 1. title ----------------------------------------------------------------------------
def title_card():
    img = turf(W, H)
    img.alpha_composite(Image.new("RGBA", (W, H), (8, 12, 26, 120)))
    d = ImageDraw.Draw(img)
    helmet = item_icon("football_helmet.png", 9)
    img.alpha_composite(helmet, (90, 120))
    shadow_text(d, (430, 120), "GRIDIRON", 210, GOLD, offset=8)
    d.text((440, 360), "American football for The Binding of Isaac: Repentance+", font=font(44), fill=WHITE)
    d.text((442, 420), "Suit up. Tackle. Kick field goals. Go All-Pro.", font=font(34, False), fill=SOFT)

    # the Quarterback suited up in a few team colors, standing on the field
    team = [("red", "blue", "white"), ("navy", "orange", "navy"), ("gold", "black", "gold"),
            ("green", "gold", "white"), ("purple", "purple", "gold"), ("pink", "white", "pink")]
    for i, (h, j, p) in enumerate(team):
        qb = quarterback(h, j, p, scale=7)
        cx = 230 + i * 292
        floor_shadow(img, cx, 872, 200)
        paste_center(img, qb, cx, 874)

    chips = ["24 ITEMS", "9 TRINKETS", "3 CARDS · 2 PILLS", "6 CHARACTERS", "3 BOSSES", "10 ENEMIES", "5 CHALLENGES"]
    x = 90
    for chip in chips:
        w = d.textlength(chip, font=font(28)) + 44
        d.rounded_rectangle((x, 930, x + w, 990), 14, fill=NAVY + (235,), outline=GOLD + (255,), width=3)
        d.text((x + w / 2, 960), chip, font=font(28), fill=GOLD, anchor="mm")
        x += w + 22
    return img


# --- 2. items ----------------------------------------------------------------------------
def items_card():
    img, d = card("33 ITEMS & TRINKETS", "Wearable gear, actives, familiars, trinkets and four Q4 legends. Every one has its own mechanic.")
    xml = (ROOT / "content/items.xml").read_text()
    entries = re.findall(r'<(passive|active|familiar|trinket) [^>]*name="([^"]+)"[^>]*gfx="([^"]+)"([^>]*)', xml)
    cards = []
    for kind, name, gfx, rest in entries:
        q = re.search(r'quality="(\d)"', rest)
        folder = "trinkets" if kind == "trinket" else "collectibles"
        cards.append((name, kind, int(q.group(1)) if q else None, icon(GFX / "items" / folder / gfx, 4)))
    order = ["passive", "active", "familiar", "trinket"]
    cards.sort(key=lambda c: (0 if c[2] == 4 else 1, order.index(c[1])))
    cols, cw, ch = 11, 164, 236
    x0, y0 = (W - cols * cw) // 2, 214
    for i, (name, kind, q, ic) in enumerate(cards):
        x, y = x0 + (i % cols) * cw, y0 + (i // cols) * ch
        legend = q == 4
        d.rounded_rectangle((x + 5, y + 5, x + cw - 5, y + ch - 5), 12,
                            fill=(255, 236, 160, 255) if legend else PAPER + (255,),
                            outline=GOLD + (255,) if legend else (90, 70, 60, 255), width=4 if legend else 2)
        img.alpha_composite(ic, (x + (cw - ic.width) // 2, y + 14))
        lines = wrap(d, name, 17, cw - 20, bold=True)
        yy = y + 156 if len(lines) == 1 else y + 146
        for line in lines[:2]:
            d.text((x + cw // 2, yy), line, font=font(17), fill=INK, anchor="ma")
            yy += 21
        tag = kind + (f"  Q{q}" if q is not None else "")
        d.text((x + cw // 2, y + ch - 30), tag.upper(), font=font(13, False),
               fill=(130, 86, 20) if legend else (96, 84, 84), anchor="ma")
    d.rounded_rectangle((W // 2 - 760, H - 120, W // 2 + 760, H - 66), 16, fill=NAVY + (230,))
    d.text((W // 2, H - 93), "Gold cards are the Q4 legends. Plus 3 cards (Coin Toss, Audible, Fair Catch) and "
           "2 pills (Timeout!, Two-Point Conversion).", font=font(24, False), fill=WHITE, anchor="mm")
    return img


# --- 3. characters ------------------------------------------------------------------------
CHARACTERS = [
    ("THE QUARTERBACK", "quarterback", "Every 3rd shot is a football: 25% faster, 25% harder.",
     ["football_helmet.png", "team_jersey.png", "playbook.png"]),
    ("TAINTED QB", "quarterback_b", "One Ball: a single heavy football that boomerangs back to him.",
     ["football_helmet.png", "shoulder_pads.png", "kicking_tee.png"]),
    ("THE KICKER", "kicker", "Special Teams: field goals refund the Tee and put points on the board.",
     ["football_cleats.png", "kicking_tee.png"]),
    ("TAINTED KICKER", "kicker_b", "Shanks: heavy lobs over the rocks; every 4th one explodes.",
     ["padded_pants.png", "pigskin.png"]),
    ("THE COACH", "coach", "His staff does the work: familiars hit 25% harder on top of BFFS!",
     ["cheerleader.png", "water_boy.png", "coachs_whistle.png"]),
    ("TAINTED COACH", "coach_b", "Can't shoot. Friendly Linemen in your colors sub in every room.",
     ["tackling_dummy.png", "coachs_whistle.png"]),
]


def characters_card():
    img, d = card("6 NEW CHARACTERS", "Three originals and three tainted versions that play completely differently.")
    pw, ph = 588, 382
    x0, y0 = (W - 3 * pw - 2 * 24) // 2, 212
    for i, (name, key, blurb, start) in enumerate(CHARACTERS):
        x, y = x0 + (i % 3) * (pw + 24), y0 + (i // 3) * (ph + 22)
        d.rounded_rectangle((x, y, x + pw, y + ph), 18, fill=PAPER + (255,), outline=(90, 70, 60, 255), width=3)
        portrait = Image.open(GFX / "ui/stage" / f"playerportrait_{key}.png").convert("RGBA")
        portrait = px(portrait.crop(portrait.getbbox()), 2)
        img.alpha_composite(portrait, (x + 18, y + (ph - portrait.height) // 2 - 10))
        tx = x + 18 + portrait.width + 18
        d.text((tx, y + 40), name, font=font(30), fill=INK)
        end = write_lines(d, (tx, y + 92), wrap(d, blurb, 24, x + pw - tx - 18), 24, (70, 56, 56))
        d.text((tx, end + 14), "STARTS WITH", font=font(14), fill=(120, 96, 80))
        for k, gfx in enumerate(start):
            img.alpha_composite(item_icon(gfx, 2), (tx + k * 70, end + 36))
    return img


# --- 4. bosses ----------------------------------------------------------------------------
def bosses_card():
    img, d = card("3 BOSSES + A MINIBOSS", "Two original boss themes: marching drumlines, brass, organ and a dark choir.")
    bosses = [
        (px(frame(GFX / "bosses/gridiron_linebacker.png", 0, 64), 5), "THE LINEBACKER",
         "Charges you down, spikes bursting footballs and jumps into a pile-up."),
        (px(frame(GFX / "bosses/gridiron_mascot_boss.png", 2, 64), 5), "THE MASCOT",
         "T-shirt cannon, belly flops, and a Spirit Squad of smaller mascots."),
        (px(frame(GFX / "monsters/gridiron_coach.png", 2, 48), 5), "THE COACH",
         "Miniboss. Calls plays for every enemy in the room and subs in linemen."),
        (px(frame(GFX / "bosses/gridiron_franchise.png", 2, 80), 4), "THE FRANCHISE",
         "Floors 7-8. Runs a route tree: slants, go routes and a Hail Mary."),
        (px(frame(GFX / "bosses/gridiron_franchise.png", 8, 80), 4), "THE STADIUM",
         "His second phase: the wave, the Kiss Cam and falling goalposts."),
    ]
    cw = W // len(bosses)
    d.rectangle((0, 716, W, 900), fill=NAVY + (215,))
    for i, (sprite, name, blurb) in enumerate(bosses):
        cx = i * cw + cw // 2
        floor_shadow(img, cx, 690, int(sprite.width * 0.7))
        paste_center(img, sprite, cx, 700)
        shadow_text(d, (cx, 730), name, 34, GOLD, anchor="ma", offset=3)
        write_lines(d, (cx, 784), wrap(d, blurb, 23, cw - 50), 23, WHITE, anchor="ma")
    return img


# --- 5. enemies ---------------------------------------------------------------------------
def enemies_card():
    img, d = card("10 FOOTBALL ENEMIES", "Built on Isaac's rules: giant black eyes, gore and colored shading. Every player in full kit.")
    foes = [("MASCOT", "mascot", 0), ("REFEREE", "referee", 0), ("LINEMAN", "lineman", 0), ("BLITZER", "blitzer", 0),
            ("PUNTER", "punter", 0), ("HUDDLE", "huddle", 0), ("COOLER", "cooler", 0), ("CHAIN GANG", "chain_gang", 0),
            ("SACKER", "sacker", 4)]
    cw = W // len(foes)
    for i, (name, sheet, idx) in enumerate(foes):
        sprite = px(frame(GFX / f"monsters/gridiron_{sheet}.png", idx, 32), 6)
        cx = i * cw + cw // 2
        floor_shadow(img, cx, 506, 140)
        paste_center(img, sprite, cx, 516)
        shadow_text(d, (cx, 534), name, 26, WHITE, anchor="ma", offset=3)

    d.rounded_rectangle((60, 610, W - 60, H - 84), 22, fill=NAVY + (225,), outline=GOLD + (255,), width=3)
    shadow_text(d, (110, 640), "TEAM CAPTAINS", 46, GOLD, offset=3)
    write_lines(d, (110, 706), wrap(d, "15% of football enemies are captains: gold trim, the gold C patch, "
                                       "more health and a twist each (three charges, a spread of punts, a huddle "
                                       "six deep...).", 25, 760), 25, WHITE)
    write_lines(d, (110, 856), wrap(d, "The Tainted Coach's own linemen suit up in your team colors.", 25, 760),
                25, GOLD)
    kits = ["lineman_captain", "huddle_captain", "punter_captain", "blitzer_captain", "lineman_team_blue",
            "lineman_team_pink", "lineman_team_green"]
    for k, sheet in enumerate(kits):
        sprite = px(frame(GFX / f"monsters/gridiron_{sheet}.png", 0, 32), 5)
        cx = 1000 + k * 130
        paste_center(img, sprite, cx, 905)
    d.text((1000 - 60, 930), "captains", font=font(20, False), fill=SOFT)
    d.text((1000 + 4 * 130 - 60, 930), "the Tainted Coach's squad", font=font(20, False), fill=SOFT)
    return img


# --- 6. uniforms --------------------------------------------------------------------------
def uniforms_card():
    img, d = card("SUIT UP IN YOUR COLORS",
                  "Helmet, jersey and pants in 11 colors each. On auto, every character wears their own.")
    combos = [(c, c, "white" if c != "white" else "navy") for c in COLORS]
    cw = W // len(combos)
    for i, (h, j, p) in enumerate(combos):
        qb = quarterback(h, j, p, scale=5)
        cx = i * cw + cw // 2
        floor_shadow(img, cx, 560, 130)
        paste_center(img, qb, cx, 562)
        shadow_text(d, (cx, 584), h.upper(), 24, WHITE, anchor="ma", offset=2)
    d.rounded_rectangle((60, 670, W - 60, H - 84), 22, fill=NAVY + (225,), outline=GOLD + (255,), width=3)
    lines = [
        ("WEAR IT", "Helmet, Shoulder Pads, Team Jersey, Padded Pants, Cleats and Eye Black all show on your character, "
                    "fitted per character: roomy helmets for big hair, horn holes for horns."),
        ("AUTO COLORS", "Magdalene suits up in pink, Judas in black and red, Cain in green and gold, Keeper in money "
                        "green; tainted characters wear darker, meaner versions. Or pick your own team."),
        ("ANY TIME", "Change helmet, jersey and pants from the settings menu mid-run. The Helmet and Team Jersey "
                     "pedestals show your colors too."),
    ]
    y = 700
    for head, body in lines:
        shadow_text(d, (110, y), head, 32, GOLD, offset=2)
        y = write_lines(d, (420, y + 4), wrap(d, body, 26, W - 540), 26, WHITE) + 20
    return img


# --- 7. features --------------------------------------------------------------------------
def features_card():
    img, d = card("MORE ON THE FIELD", "Events, transformations, challenges and dozens of base-game synergies.")
    decor = Image.open(GFX / "effects/gridiron_decor.png").convert("RGBA")
    tiles = [
        ("SUITED UP", "Wear 3+ pieces of gear: +1 damage, tackles go live twice as fast, and a gold glow.",
         item_icon("team_jersey.png")),
        ("ALL-PRO", "Hold any 3 Gridiron items: +0.5 damage, golden spirals and gold war paint.",
         item_icon("golden_arm.png")),
        ("HALFTIME SHOW", "Sometimes clearing a room starts the show: fireworks, then new gear or a soul heart.",
         item_icon("foam_finger.png")),
        ("PRO SHOP", "Some shops are team stores that stock a Gridiron item you don't have yet.",
         item_icon("super_bowl_ring.png")),
        ("FOOTBALL FIELDS", "Some rooms have a faded field painted on the floor, old iron goalposts and all.",
         None),
        ("5 CHALLENGES", "Fourth and Long, Two-Minute Drill, Ground Game, Special Teams and Sudden Death.",
         item_icon("coachs_whistle.png")),
        ("SYNERGIES", "Mars dashes are tackles, steroids make you Juiced, footballs take on your tear effects, "
                      "and more. All listed in EID.", item_icon("football_helmet.png")),
        ("YOUR SETTINGS", "A settings menu for tuning, colors, content toggles, music and costume fit.",
         item_icon("playbook.png")),
    ]
    goal = None
    m = re.search(r'Name="Goalpost".*?XCrop="(\d+)" YCrop="(\d+)" Width="(\d+)" Height="(\d+)"',
                  (GFX / "effects/gridiron_decor.anm2").read_text(), re.S)
    if m:
        x, y, w, h = map(int, m.groups())
        goal = decor.crop((x, y, x + w, y + h))
        goal = px(goal.crop(goal.getbbox()), 1)
    tw, th = 438, 380
    x0, y0 = (W - 4 * tw - 3 * 20) // 2, 210
    for i, (name, blurb, ic) in enumerate(tiles):
        x, y = x0 + (i % 4) * (tw + 20), y0 + (i // 4) * (th + 20)
        d.rounded_rectangle((x, y, x + tw, y + th), 18, fill=PAPER + (255,), outline=(90, 70, 60, 255), width=3)
        sprite = ic if ic is not None else goal
        if sprite is not None:
            img.alpha_composite(sprite, (x + (tw - sprite.width) // 2, y + 24 + max(0, 110 - sprite.height)))
        d.text((x + tw // 2, y + 160), name, font=font(32), fill=INK, anchor="ma")
        write_lines(d, (x + tw // 2, y + 212), wrap(d, blurb, 24, tw - 48), 24, (70, 56, 56), anchor="ma")
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cards = {
        "01_title.png": title_card(),
        "02_items.png": items_card(),
        "03_characters.png": characters_card(),
        "04_bosses.png": bosses_card(),
        "05_enemies.png": enemies_card(),
        "06_uniforms.png": uniforms_card(),
        "07_features.png": features_card(),
    }
    for name, img in cards.items():
        img.convert("RGB").save(OUT / name, optimize=True)
        print(OUT.relative_to(ROOT) / name, img.size)


if __name__ == "__main__":
    main()
