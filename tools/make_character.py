"""Build The Quarterback's and The Kicker's sprites and menu art.

Inputs (not vendored, both public):
  * the CC0 character template: https://github.com/manaphoenix/IsaacTemplates (template_character)
  * the costume templates:      https://github.com/catinsurance/isaac-costume-templates

    python3 tools/make_character.py <IsaacTemplates>/template_character <isaac-costume-templates>

Run tools/make_costumes.py first: the figure is drawn wearing the real costume sheets.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "resources/gfx"
CONTENT = ROOT / "content/gfx"
COSTUMES = RES / "characters/costumes"

NAME = "Quarterback"
FONT_PATHS = [
    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]
INK = (58, 38, 42, 255)
INK_TAINTED = (110, 24, 28, 255)
NAME_TAG = (214, 196, 160, 255)

# grey template skin -> Isaac skin (normal) / bruised pale (tainted)
SKIN_NORMAL = {227: (227, 198, 197), 207: (207, 156, 155), 186: (185, 115, 113)}
SKIN_TAINTED = {227: (206, 200, 214), 207: (166, 156, 182), 186: (122, 108, 140)}


def font(size):
    for path in FONT_PATHS:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def text_image(text, size, color, outline=None):
    """Crisp (non-antialiased) text, optionally with a 1px outline."""
    f = font(size)
    box = f.getbbox(text)
    w, h = box[2] - box[0] + 4, box[3] - box[1] + 4
    mask = Image.new("1", (w, h), 0)
    ImageDraw.Draw(mask).text((2 - box[0], 2 - box[1]), text, font=f, fill=1)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px, m = img.load(), mask.load()
    for y in range(h):
        for x in range(w):
            if m[x, y]:
                px[x, y] = color
    if outline:
        out = img.copy()
        o = out.load()
        for y in range(h):
            for x in range(w):
                if not m[x, y] and any(0 <= x + dx < w and 0 <= y + dy < h and m[x + dx, y + dy]
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    o[x, y] = outline
        img = out
    return img


def recolor_skin(img, mapping):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a and r == g == b:
                for grey, col in mapping.items():
                    if abs(r - grey) <= 3:
                        px[x, y] = col + (a,)
                        break
    return out


def figure(costume_templates, tainted=False, kind="qb"):
    """Front-facing figure on Isaac's rig: the Quarterback in helmet, eye black and jersey;
    the Kicker in his headband and cleats (pants too when tainted)."""
    t = Path(costume_templates) / "compact/normal"
    head = Image.open(t / "compact_head.png").convert("RGBA").crop((0, 0, 32, 32))
    body = Image.open(t / "compact_body.png").convert("RGBA").crop((0, 64, 32, 96))
    if tainted:
        head, body = recolor_tainted(head), recolor_tainted(body)
    fig = Image.new("RGBA", (40, 44), (0, 0, 0, 0))

    def layer(img, sheet, crop):
        part = Image.open(COSTUMES / f"{sheet}.png").convert("RGBA").crop(crop)
        img.alpha_composite(part)

    b = body.copy()
    h = head.copy()
    if kind == "kicker":
        layer(b, "gridiron_legs_pantscleats" if tainted else "gridiron_legs_cleats", (0, 64, 32, 96))
        layer(h, "gridiron_kicker_headband_b" if tainted else "gridiron_kicker_headband", (0, 0, 32, 32))
    elif tainted:
        # Tainted QB, as he starts: bare pads (no jersey), a cracked and bloodied helmet
        layer(b, "gridiron_torso_pads", (0, 64, 32, 96))
        layer(h, "gridiron_helmet", (0, 0, 32, 32))
        hp = h.load()
        for x, y in ((12, 2), (13, 3), (12, 4), (13, 5), (14, 6), (13, 7)):
            hp[x, y] = (40, 14, 16, 255)                             # crack through the shell
        for x, y in ((19, 3), (19, 4), (20, 5), (19, 6), (20, 7), (20, 8), (21, 9)):
            hp[x, y] = (150, 10, 18, 255)                            # blood running down
    else:
        layer(b, "gridiron_legs_cleats", (0, 64, 32, 96))
        layer(b, "gridiron_torso_jerseypads", (0, 64, 32, 96))
        layer(h, "gridiron_eyeblack", (0, 0, 32, 32))
        layer(h, "gridiron_helmet", (0, 0, 32, 32))
    fig.alpha_composite(b, (4, 10))
    fig.alpha_composite(h, (4, 0))
    return fig


def recolor_tainted(img):
    """Isaac's pink skin -> the tainted pale tone."""
    mapping = {(227, 198, 197): (206, 200, 214), (207, 156, 155): (166, 156, 182), (185, 115, 113): (122, 108, 140)}
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (p[3],)
    return out


def clear(img, box, color=(0, 0, 0, 0)):
    ImageDraw.Draw(img).rectangle(box, fill=color)


def paste_center(dst, src, box):
    x0, y0, x1, y1 = box
    dst.alpha_composite(src, (x0 + (x1 - x0 - src.width) // 2, y0 + (y1 - y0 - src.height) // 2))


def scaled(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def play_diagram(page, x0, y0, ink):
    """A little X's and O's doodle in the corner of the page."""
    d = ImageDraw.Draw(page)
    for i in range(3):
        cx = x0 + i * 14
        d.ellipse((cx, y0, cx + 6, y0 + 6), outline=ink)
        d.line((cx, y0 + 16, cx + 6, y0 + 22), fill=ink)
        d.line((cx + 6, y0 + 16, cx, y0 + 22), fill=ink)
    d.line((x0 + 3, y0 + 7, x0 + 3, y0 + 12), fill=ink)
    d.line((x0 + 17, y0 + 7, x0 + 30, y0 - 4), fill=ink)
    d.line((x0 + 30, y0 - 4, x0 + 26, y0 - 3), fill=ink)


def draw_page(template_page, name, tag, title_ink, fig, sheet, page_at, name_box, portrait_box):
    """One character-select page: the template page with our title and play diagram (the
    middle stays blank for the character wheel), plus the name tag and wheel portrait."""
    page = template_page.copy()
    paper = page.getpixel((240, 130))
    clear(page, (150, 24, 332, 64), paper)
    paste_center(page, text_image(name.upper(), 22, title_ink), (128, 24, 352, 60))
    play_diagram(page, 150, 222, title_ink)
    clear(sheet, (page_at[0], page_at[1], page_at[0] + PAGE[0] - 1, page_at[1] + PAGE[1] - 1))
    sheet.alpha_composite(page, page_at)
    clear(sheet, name_box)
    paste_center(sheet, text_image(tag, 20, title_ink), name_box)
    clear(sheet, portrait_box)
    x0, y0, x1, y1 = portrait_box
    sheet.alpha_composite(fig, (x0 + (x1 - x0 - fig.width) // 2, y1 - fig.height + 1))


PAGE = (480, 270)


def rename_anm2(src, dst, sheet_renames=None):
    text = Path(src).read_text()
    text = text.replace('Name="Alpha"', f'Name="{NAME}"').replace('DefaultAnimation="Alpha"', f'DefaultAnimation="{NAME}"')
    for old, new in (sheet_renames or {}).items():
        text = text.replace(f'Path="{old}"', f'Path="{new}"')
    Path(dst).write_text(text)


def add_animation(path, name, crop_moves):
    """Append a copy of the Quarterback animation under another name, with some crops moved
    (each modded character is one animation in these menu files)."""
    text = Path(path).read_text()
    start = text.index(f'<Animation Name="{NAME}"')
    end = text.index("</Animation>", start) + len("</Animation>")
    anim = text[start:end].replace(f'Name="{NAME}"', f'Name="{name}"', 1)
    for (x, y, w, h), (nx, ny) in crop_moves:
        old = f'XCrop="{x}" YCrop="{y}" Width="{w}" Height="{h}"'
        assert old in anim, f"{path}: no crop {old}"
        anim = anim.replace(old, f'XCrop="{nx}" YCrop="{ny}" Width="{w}" Height="{h}"')
    Path(path).write_text(text[:end] + "\n    " + anim + text[end:])


# Where the Kicker's menu art lives (free space on the Quarterback's sheets).
KICKER = {
    "page": (0, 560), "page_alt": (0, 548),
    "name": (200, 300), "portrait": (300, 300), "name_alt": (200, 300), "portrait_alt": (300, 300),
    "coop": (0, 40), "death": (450, 180), "death_alt": (443, 210),
}


def box(x, y, w, h):
    return (x, y, x + w - 1, y + h - 1)


def main(template_dir, costume_templates):
    T = Path(template_dir)
    CONTENT.mkdir(parents=True, exist_ok=True)
    (RES / "ui/boss").mkdir(parents=True, exist_ok=True)
    (RES / "ui/stage").mkdir(parents=True, exist_ok=True)

    # in-game sprite sheets
    sheet = Image.open(T / "resources/gfx/characters/costumes/character_template.png").convert("RGBA")
    recolor_skin(sheet, SKIN_NORMAL).save(COSTUMES / "character_quarterback.png")
    recolor_skin(sheet, SKIN_TAINTED).save(COSTUMES / "character_quarterback_b.png")

    fig = figure(costume_templates)
    fig_b = figure(costume_templates, tainted=True)

    kick = figure(costume_templates, kind="kicker")
    kick_b = figure(costume_templates, tainted=True, kind="kicker")
    recolor_skin(sheet, SKIN_NORMAL).save(COSTUMES / "character_kicker.png")
    recolor_skin(sheet, SKIN_TAINTED).save(COSTUMES / "character_kicker_b.png")

    # character select pages (sheet names match what the anm2 files reference)
    K = KICKER
    for tpl, out, ink, f, kf, nb, pb, page_at, knb, kpb in (
            ("charactermenu.png", "CharacterMenu.png", INK, fig, kick, box(16, 913, 57, 31), box(8, 940, 38, 57),
             K["page"], box(*K["name"], 57, 31), box(*K["portrait"], 38, 57)),
            ("charactermenualt.png", "CharacterMenuAlt.png", INK_TAINTED, fig_b, kick_b, box(136, 817, 74, 29),
             box(10, 924, 45, 65), K["page_alt"], box(*K["name_alt"], 74, 29), box(*K["portrait_alt"], 45, 65))):
        sheet_img = Image.open(T / "content/gfx" / tpl).convert("RGBA")
        template_page = sheet_img.crop((0, 0) + PAGE)
        draw_page(template_page, NAME, "QB", ink, f, sheet_img, (0, 0), nb, pb)
        draw_page(template_page, "Kicker", "PK", ink, kf, sheet_img, page_at, knb, kpb)
        sheet_img.save(CONTENT / out)

    # co-op select heads
    for src, dst, f, kf in (("coop menu.png", "coop menu.png", fig, kick), ("coop menu b.png", "coop menu b.png", fig_b, kick_b)):
        img = Image.open(T / "content/gfx" / src).convert("RGBA")
        clear(img, (0, 0, 33, 31))
        img.alpha_composite(f.crop((4, 0, 36, 28)), (1, 2))
        cx, cy = K["coop"]
        clear(img, (cx, cy, cx + 33, cy + 31))
        img.alpha_composite(kf.crop((4, 0, 36, 28)), (cx + 1, cy + 2))
        img.save(CONTENT / dst)

    # death screen names
    death = Image.open(T / "content/gfx/death portraits.png").convert("RGBA")
    for b, ink, tag in ((box(450, 125, 51, 22), INK, "QB"), (box(443, 148, 67, 27), INK_TAINTED, "QB"),
                        (box(*K["death"], 51, 22), INK, "PK"), (box(*K["death_alt"], 67, 27), INK_TAINTED, "PK")):
        clear(death, b)
        paste_center(death, text_image(tag, 18, ink), b)
    death.save(CONTENT / "death portraits.png")

    for name in ("charactermenu", "charactermenualt", "characterportraits", "characterportraitsalt",
                 "coop menu", "coop menu alt", "death screen", "death screen alt"):
        rename_anm2(T / f"content/gfx/{name}.anm2", CONTENT / f"{name}.anm2")
    G = CONTENT
    add_animation(G / "charactermenu.anm2", "Kicker", [((0, 0, 480, 270), K["page"]), ((16, 913, 57, 31), K["name"])])
    add_animation(G / "charactermenualt.anm2", "Kicker", [((0, 0, 480, 270), K["page_alt"]), ((136, 817, 74, 29), K["name_alt"])])
    add_animation(G / "characterportraits.anm2", "Kicker", [((8, 940, 38, 57), K["portrait"])])
    add_animation(G / "characterportraitsalt.anm2", "Kicker", [((10, 924, 45, 65), K["portrait_alt"])])
    add_animation(G / "coop menu.anm2", "Kicker", [((0, 0, 32, 32), K["coop"])])
    add_animation(G / "coop menu alt.anm2", "Kicker", [((0, 0, 32, 32), K["coop"])])
    add_animation(G / "death screen.anm2", "Kicker", [((450, 125, 51, 22), K["death"])])
    add_animation(G / "death screen alt.anm2", "Kicker", [((443, 148, 67, 27), K["death_alt"])])

    # VS screen name + stage portrait
    for who, title, suffix, ink, f in (("quarterback", NAME, "", NAME_TAG, fig),
                                       ("quarterback", NAME, "_b", (196, 150, 150, 255), fig_b),
                                       ("kicker", "Kicker", "", NAME_TAG, kick),
                                       ("kicker", "Kicker", "_b", (196, 150, 150, 255), kick_b)):
        tag = Image.new("RGBA", (192, 64), (0, 0, 0, 0))
        paste_center(tag, text_image(title.upper(), 24, ink, outline=(40, 30, 30, 255)), (0, 0, 191, 63))
        tag.save(RES / f"ui/boss/playername_{who}{suffix}.png")
        portrait = Image.new("RGBA", (144, 144), (0, 0, 0, 0))
        paste_center(portrait, scaled(f, 3), (0, 0, 143, 143))
        portrait.save(RES / f"ui/stage/playerportrait_{who}{suffix}.png")
    print("character art written")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
