"""Build The Quarterback's sprites and menu art.

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


def figure(costume_templates, tainted=False):
    """Front-facing Quarterback: Isaac's rig wearing the helmet, eye black and jersey."""
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
    layer(b, "gridiron_legs_pantscleats" if tainted else "gridiron_legs_cleats", (0, 64, 32, 96))
    layer(b, "gridiron_torso_jerseypads", (0, 64, 32, 96))
    h = head.copy()
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


def build_menu(template_png, out_png, title_ink, fig, name_box, portrait_box):
    page = Image.open(template_png).convert("RGBA")
    # replace "WHO AM I?" with the name: paint over the old title with paper colour
    paper = page.getpixel((240, 130))
    clear(page, (150, 24, 332, 64), paper)
    title = text_image(NAME.upper(), 22, title_ink)
    paste_center(page, title, (128, 24, 352, 60))
    # a big drawing of him on the page, plus a play diagram
    paste_center(page, scaled(fig, 3), (160, 68, 320, 214))
    play_diagram(page, 150, 222, title_ink)
    # the little name tag and the wheel portrait
    clear(page, name_box)
    paste_center(page, text_image("QB", 20, title_ink), name_box)
    clear(page, portrait_box)
    x0, y0, x1, y1 = portrait_box
    page.alpha_composite(fig, (x0 + (x1 - x0 - fig.width) // 2, y1 - fig.height + 1))
    page.save(out_png)


def rename_anm2(src, dst, sheet_renames=None):
    text = Path(src).read_text()
    text = text.replace('Name="Alpha"', f'Name="{NAME}"').replace('DefaultAnimation="Alpha"', f'DefaultAnimation="{NAME}"')
    for old, new in (sheet_renames or {}).items():
        text = text.replace(f'Path="{old}"', f'Path="{new}"')
    Path(dst).write_text(text)


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

    # character select pages (sheet names match what the anm2 files reference)
    build_menu(T / "content/gfx/charactermenu.png", CONTENT / "CharacterMenu.png", INK, fig,
               box(16, 913, 57, 31), box(8, 940, 38, 57))
    build_menu(T / "content/gfx/charactermenualt.png", CONTENT / "CharacterMenuAlt.png", INK_TAINTED, fig_b,
               box(136, 817, 74, 29), box(10, 924, 45, 65))

    # co-op select heads
    for src, dst, f in (("coop menu.png", "coop menu.png", fig), ("coop menu b.png", "coop menu b.png", fig_b)):
        img = Image.open(T / "content/gfx" / src).convert("RGBA")
        clear(img, (0, 0, 33, 31))
        img.alpha_composite(f.crop((4, 0, 36, 28)), (1, 2))
        img.save(CONTENT / dst)

    # death screen names
    death = Image.open(T / "content/gfx/death portraits.png").convert("RGBA")
    for b, ink in ((box(450, 125, 51, 22), INK), (box(443, 148, 67, 27), INK_TAINTED)):
        clear(death, b)
        paste_center(death, text_image("QB", 18, ink), b)
    death.save(CONTENT / "death portraits.png")

    for name in ("charactermenu", "charactermenualt", "characterportraits", "characterportraitsalt",
                 "coop menu", "coop menu alt", "death screen", "death screen alt"):
        rename_anm2(T / f"content/gfx/{name}.anm2", CONTENT / f"{name}.anm2")

    # VS screen name + stage portrait
    for suffix, ink, f in (("", NAME_TAG, fig), ("_b", (196, 150, 150, 255), fig_b)):
        tag = Image.new("RGBA", (192, 64), (0, 0, 0, 0))
        paste_center(tag, text_image(NAME.upper(), 24, ink, outline=(40, 30, 30, 255)), (0, 0, 191, 63))
        tag.save(RES / f"ui/boss/playername_quarterback{suffix}.png")
        portrait = Image.new("RGBA", (144, 144), (0, 0, 0, 0))
        paste_center(portrait, scaled(f, 3), (0, 0, 143, 143))
        portrait.save(RES / f"ui/stage/playerportrait_quarterback{suffix}.png")
    print("character art written")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
