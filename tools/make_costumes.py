"""Generate Gridiron costume spritesheets + anm2 files.

The costumes are painted procedurally on top of Isaac's head/body silhouette so
they line up with the vanilla player rig. The silhouette comes from the public
costume templates at https://github.com/catinsurance/isaac-costume-templates
(compact/normal), which are not vendored here.

Usage (from the repo root):
    git clone --depth 1 https://github.com/catinsurance/isaac-costume-templates /tmp/ict
    python3 tools/make_costumes.py /tmp/ict
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CHAR_DIR = ROOT / "resources/gfx/characters"
SHEET_DIR = CHAR_DIR / "costumes"

CELL = 32
OUTLINE = (20, 12, 12, 255)
CLEAR = (0, 0, 0, 0)

# Isaac's skin tones in the template -> shade index (0 = dark, 1 = mid, 2 = light)
SKIN_SHADE = {
    (185, 115, 113): 0,
    (207, 156, 155): 1,
    (227, 198, 197): 2,
}

# helmet shell tones: dark rim, mid, light, gloss highlight
HELMET = [(118, 14, 22, 255), (176, 28, 38, 255), (218, 50, 58, 255), (250, 150, 150, 255)]
HELMET_STRIPE = (246, 246, 242, 255)
HELMET_STRIPE_SHADE = (200, 200, 196, 255)
BUMPER = [(52, 52, 60, 255), (92, 92, 104, 255)]       # front/back bumper plates
FACEMASK = (214, 218, 226, 255)                         # bar top (lit)
FACEMASK_SHADE = (126, 130, 142, 255)                   # bar underside
CHIN_CUP = (240, 240, 236, 255)
INTERIOR = (40, 18, 20, 255)                            # inside of the helmet (item icon)
EYE_BLACK = (22, 22, 26, 255)
EYE_BLACK_SHINE = (70, 70, 80, 255)

JERSEY = [(25, 45, 120, 255), (40, 75, 175, 255), (70, 110, 210, 255)]
JERSEY_TRIM = (240, 200, 50, 255)
PADS = [(165, 165, 160, 255), (215, 215, 210, 255), (240, 240, 236, 255)]
PANTS = [(170, 170, 165, 255), (215, 215, 210, 255), (242, 242, 238, 255)]
CLEATS = [(20, 20, 24, 255), (40, 40, 46, 255), (60, 60, 68, 255)]

TORSO_LAST_ROW = 19   # body cell rows <= this are torso, below are legs


# --- helpers -----------------------------------------------------------------
def is_dark(px):
    return px[3] and px[0] + px[1] + px[2] < 150


def shade_of(px):
    if not px[3] or is_dark(px):
        return None
    if px[:3] in SKIN_SHADE:
        return SKIN_SHADE[px[:3]]
    lum = sum(px[:3]) / 3
    return 2 if lum > 190 else 1 if lum > 150 else 0


def cells(img):
    for cy in range(0, img.height - CELL + 1, CELL):
        for cx in range(0, img.width - CELL + 1, CELL):
            yield cx, cy


def outline_mask(mask, w, h):
    """Pixels adjacent (4-way) to the mask but not in it."""
    out = set()
    for (x, y) in mask:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in mask and 0 <= p[0] < w and 0 <= p[1] < h:
                out.add(p)
    return out


# --- head costumes -----------------------------------------------------------
# compact head sheet: [down, down-shoot, right, right-shoot, up, up-shoot]
def head_frames(template):
    for i in range(6):
        view = ("down", "right", "up")[i // 2]
        yield i, view, template.crop((i * CELL, 0, (i + 1) * CELL, CELL))


def silhouette(src):
    """Head pixels and per-row extents from the template frame."""
    s = src.load()
    mask = {(x, y) for y in range(CELL) for x in range(CELL) if s[x, y][3]}
    rows = {}
    for (x, y) in mask:
        lo, hi = rows.get(y, (x, x))
        rows[y] = (min(lo, x), max(hi, x))
    return mask, rows


def shell_tone(x, y, edge, light=(10, 6)):
    """Gloss shading: bright near the light spot, dark at the rim."""
    if edge:
        return HELMET[0]
    if (x, y) in ((light[0], light[1]), (light[0] + 1, light[1] - 1), (light[0] - 1, light[1] + 1)):
        return HELMET[3]
    d = ((x - light[0]) ** 2 + (y - light[1]) ** 2) ** 0.5
    if d < 9:
        return HELMET[2]
    return HELMET[1]


def bar(o, points, shade_below=True):
    """A facemask bar: lit pixels with a darker underside so it reads as round."""
    pts = set(points)
    for (x, y) in pts:
        o[x, y] = FACEMASK
    if shade_below:
        for (x, y) in pts:
            if (x, y + 1) not in pts and 0 <= y + 1 < CELL:
                o[x, y + 1] = FACEMASK_SHADE


def paint_helmet(src, view):
    """Modern helmet: bulkier glossy shell, center stripe, bumpers, cage facemask."""
    out = Image.new("RGBA", (CELL, CELL), CLEAR)
    o = out.load()
    mask, rows = silhouette(src)

    def in_shell(x, y):
        if (x, y) not in mask:
            return False
        lo, hi = rows[y]
        if view == "up":
            return True
        if y <= 11:
            return True
        if view == "down":
            side = 3 if y <= 17 else 4          # jaw guards widen toward the chin
            return y <= 23 and (x - lo <= side or hi - x <= side)
        # side view: back of the head and the jaw guard, face opening in front
        if y <= 22:
            return x <= 17
        return x <= 19

    shell = {(x, y) for (x, y) in mask if in_shell(x, y)}
    # helmets sit taller than a bare head: add one row on top of the crown
    grown = set(shell)
    for (x, y) in shell:
        if y <= 4 and (x, y - 1) not in mask and y - 1 >= 0:
            grown.add((x, y - 1))
    rim = outline_mask(grown, CELL, CELL)
    for (x, y) in grown:
        near_rim = any((x + dx, y + dy) in rim for dx, dy in ((1, 0), (0, 1), (1, 1)))
        o[x, y] = shell_tone(x, y, near_rim and (x > 15 or y > 14))
    for (x, y) in rim:
        o[x, y] = OUTLINE

    if view == "down":
        # center stripe with a shaded edge
        for y in range(1, 12):
            for x, col in ((15, HELMET_STRIPE), (16, HELMET_STRIPE_SHADE)):
                if (x, y) in grown and o[x, y] != OUTLINE:
                    o[x, y] = col
        # brow edge of the shell, with the mask's top bar tucked under it
        for x in range(rows[11][0] + 4, rows[11][1] - 3):
            o[x, 11] = HELMET[0]
        # inner edge of the jaw guards in shadow
        for y in range(12, 24):
            lo, hi = rows[y]
            side = 3 if y <= 17 else 4
            for x in (lo + side, hi - side):
                if (x, y) in grown:
                    o[x, y] = HELMET[0]
        # forehead badge (like the Schutt / Riddell front plate)
        for x in range(14, 18):
            o[x, 9] = BUMPER[1]
            o[x, 10] = HELMET_STRIPE
        o[13, 10] = BUMPER[0]
        o[18, 10] = BUMPER[0]
        # facemask, modeled on a modern wrap-around cage: the eyes stay open and the
        # bars sweep back from the nose bar to the temple clips instead of boxing the face
        for x in (9, 10, 21, 22):                                       # bar stubs at the temple clips
            o[x, 12] = FACEMASK
        for x, y in ((8, 12), (23, 12)):                                # temple clips
            o[x, y] = BUMPER[1]
        sweep = [(9, 13), (8, 14), (8, 15), (7, 16), (6, 17), (6, 18)]
        for x, y in sweep:                                              # side sweeps (angled away: darker)
            o[x, y] = FACEMASK_SHADE
            o[31 - x, y] = FACEMASK_SHADE
        bar(o, [(x, 19) for x in range(6, 26)])                         # nose bar, right under the eyes
        bar(o, [(7, 21), (8, 22)] + [(x, 22) for x in range(9, 23)] + [(23, 22), (24, 21)])  # chin bar
        for x in (13, 18):                                              # twin center verticals
            o[x, 21] = FACEMASK
        # chin cup
        for x in range(13, 19):
            o[x, 24] = CHIN_CUP
        for x in range(12, 20):
            o[x, 25] = OUTLINE
        o[12, 24] = OUTLINE
        o[19, 24] = OUTLINE

    elif view == "right":
        # stripe along the crown
        for x in range(8, 25):
            col = [y for y in range(CELL) if (x, y) in grown and o[x, y] != OUTLINE]
            if col:
                o[x, col[0]] = HELMET_STRIPE
        # brow bumper, vents, ear hole, jaw-guard seam
        for x in range(18, 26):
            if (x, 11) in grown or (x, 11) in mask:
                o[x, 11] = BUMPER[1]
            o[x, 12] = BUMPER[0]
        for x, y in ((7, 6), (8, 6), (11, 4), (12, 4)):
            o[x, y] = BUMPER[0]
        for x, y in ((9, 15), (10, 15), (9, 16), (10, 16)):
            o[x, y] = OUTLINE
        for x, y in ((8, 15), (11, 15), (8, 16), (11, 16), (9, 14), (10, 14), (9, 17), (10, 17)):
            o[x, y] = BUMPER[1]
        for x, y in ((12, 19), (13, 20), (14, 21), (15, 22), (16, 23)):
            o[x, y] = HELMET[0]
        # rear bumper at the base of the shell
        for x in range(3, 9):
            if (x, 22) in grown:
                o[x, 22] = BUMPER[0]
        # facemask: clips at the temple and jaw, sweeps forward to a rounded front
        bar(o, [(x, 13) for x in range(19, 26)])                        # top bar
        for x, y in ((26, 14), (27, 15)):                               # brow curve down to the nose bar
            o[x, y] = FACEMASK
        for x, y in ((20, 14), (21, 15)):                               # side sweep to the nose bar
            o[x, y] = FACEMASK_SHADE
        bar(o, [(x, 16) for x in range(19, 30)])                        # nose bar
        bar(o, [(x, 19) for x in range(20, 30)])                        # lower bar
        for y in range(17, 19):                                         # front of the cage
            o[29, y] = FACEMASK_SHADE
        for x, y in ((29, 20), (28, 21), (27, 22)):                       # rounded chin
            o[x, y] = FACEMASK_SHADE
        for x in range(21, 27):                                         # chin bar
            o[x, 22] = FACEMASK_SHADE
        for x in range(21, 25):                                         # chin cup
            o[x, 23] = CHIN_CUP
            o[x, 24] = OUTLINE
        for y in range(14, 24):                                         # outline the protruding front
            for x in range(1, CELL):
                if x >= 28 and o[x - 1, y][3] and o[x - 1, y] != OUTLINE and not o[x, y][3]:
                    o[x, y] = OUTLINE
                    break

    else:  # up / back of the helmet
        for y in range(1, 26):
            for x, col in ((15, HELMET_STRIPE), (16, HELMET_STRIPE_SHADE)):
                if (x, y) in grown and o[x, y] != OUTLINE:
                    o[x, y] = col
        lo, hi = rows[23]
        for x in range(lo + 3, hi - 2):                                 # rear bumper
            if (x, 23) in grown:
                o[x, 23] = BUMPER[1]
                o[x, 24] = BUMPER[0]
    return out


def helmet_item_icon(src):
    """The collectible sprite: the side view with the face opening filled in."""
    icon = paint_helmet(src, "right")
    o = icon.load()
    mask, _ = silhouette(src)
    for (x, y) in mask:
        if not o[x, y][3]:
            o[x, y] = INTERIOR
    return icon


def paint_eye_black(src, view):
    out = Image.new("RGBA", (CELL, CELL), CLEAR)
    o = out.load()
    if view == "down":
        # one row of skin between the eye and the stripe so they read separately
        for x0, x1 in ((6, 10), (21, 25)):
            for x in range(x0, x1 + 1):
                o[x, 20] = EYE_BLACK
            for x in range(x0 + 1, x1):
                o[x, 21] = EYE_BLACK
            o[x0 + 1, 20] = EYE_BLACK_SHINE
    elif view == "right":
        for x in range(16, 21):
            o[x, 19] = EYE_BLACK
        for x in range(17, 20):
            o[x, 20] = EYE_BLACK
        o[17, 19] = EYE_BLACK_SHINE
    return out


# --- body costumes -----------------------------------------------------------
def body_frame_info(cell):
    s = cell.load()
    mask = {(x, y) for y in range(CELL) for x in range(CELL) if s[x, y][3]}
    return s, mask


def paint_torso(cell, jersey, pads, side_view):
    out = Image.new("RGBA", (CELL, CELL), CLEAR)
    s, mask = body_frame_info(cell)
    o = out.load()
    if not mask:
        return out

    if jersey:
        for (x, y) in mask:
            if y > TORSO_LAST_ROW:
                continue
            px = s[x, y]
            if is_dark(px):
                o[x, y] = OUTLINE
            else:
                o[x, y] = JERSEY_TRIM if y == TORSO_LAST_ROW else JERSEY[shade_of(px)]

    if pads:
        row = [x for (x, y) in mask if y == 16]
        if row:
            xl, xr = min(row), max(row)
            if side_view:
                cx = (xl + xr) // 2
                boxes = [(cx - 4, cx + 3)]
            else:
                boxes = [(xl - 1, xl + 5), (xr - 5, xr + 1)]
            pad = set()
            for x0, x1 in boxes:
                w = x1 - x0
                for y in range(14, 19):
                    inset = 1 if y in (14, 18) else 0
                    for x in range(x0 + inset, x1 + 1 - inset):
                        if 0 <= x < CELL:
                            pad.add((x, y))
            for (x, y) in outline_mask(pad, CELL, CELL):
                o[x, y] = OUTLINE
            for (x, y) in pad:
                if jersey:
                    # jersey stretched over the pads: team fabric with sleeve stripes
                    if y == 17:
                        o[x, y] = JERSEY_TRIM
                    else:
                        o[x, y] = JERSEY[2] if y <= 14 else JERSEY[1] if y <= 16 else JERSEY[0]
                else:
                    o[x, y] = PADS[2] if y <= 15 else PADS[1] if y <= 17 else PADS[0]
    return out


def paint_legs(cell, pants, cleats):
    out = Image.new("RGBA", (CELL, CELL), CLEAR)
    s, mask = body_frame_info(cell)
    o = out.load()
    if not mask:
        return out

    legs = {(x, y) for (x, y) in mask if y > TORSO_LAST_ROW and not is_dark(s[x, y])}
    feet = set()
    if cleats:
        for x in {x for (x, _) in legs}:
            col = sorted(y for (xx, y) in legs if xx == x)
            feet.add((x, col[-1]))

    for (x, y) in mask:
        if y <= TORSO_LAST_ROW:
            continue
        px = s[x, y]
        if is_dark(px):
            if pants or (cleats and any((x + dx, y + dy) in feet for dx in (-1, 0, 1) for dy in (-1, 0, 1))):
                o[x, y] = OUTLINE
            continue
        if (x, y) in feet:
            o[x, y] = CLEATS[shade_of(px)]
        elif pants:
            o[x, y] = PANTS[shade_of(px)]
    return out


# --- anm2 --------------------------------------------------------------------
def write_anm2(template_path, out_path, sheet_rel, layer_name, old_layer):
    text = Path(template_path).read_text()
    text = text.replace('Path="compact_head.png"', f'Path="{sheet_rel}"')
    text = text.replace('Path="compact_body.png"', f'Path="{sheet_rel}"')
    text = text.replace(f'Layer Name="{old_layer}"', f'Layer Name="{layer_name}"')
    text = text.replace('CreatedBy=""', 'CreatedBy="Gridiron tools/make_costumes.py"')
    out_path.write_text(text)


def main(template_root):
    tdir = Path(template_root) / "compact/normal"
    head = Image.open(tdir / "compact_head.png").convert("RGBA")
    body = Image.open(tdir / "compact_body.png").convert("RGBA")
    if body.height % CELL:
        padded = Image.new("RGBA", (body.width, (body.height // CELL + 1) * CELL), CLEAR)
        padded.paste(body, (0, 0))
        body = padded

    SHEET_DIR.mkdir(parents=True, exist_ok=True)

    head_costumes = {
        "gridiron_helmet": (paint_helmet, "head5"),
        "gridiron_eyeblack": (paint_eye_black, "head1"),
    }
    # the collectible sprite is the costume's side view, so they always match
    helmet_item_icon(head.crop((2 * CELL, 0, 3 * CELL, CELL))).save(
        ROOT / "resources/gfx/items/collectibles/football_helmet.png")

    for name, (painter, layer) in head_costumes.items():
        sheet = Image.new("RGBA", head.size, CLEAR)
        for i, view, frame in head_frames(head):
            sheet.paste(painter(frame, view), (i * CELL, 0))
        sheet.save(SHEET_DIR / f"{name}.png")
        write_anm2(tdir / "compact_head.anm2", CHAR_DIR / f"{name}.anm2",
                   f"costumes/{name}.png", layer, "head0")

    # body rows 0-1 are the side view (right / left), rows 2-3 front/back
    torso = {
        "gridiron_torso_jersey": (True, False),
        "gridiron_torso_pads": (False, True),
        "gridiron_torso_jerseypads": (True, True),
    }
    for name, (jersey, pads) in torso.items():
        sheet = Image.new("RGBA", body.size, CLEAR)
        for cx, cy in cells(body):
            cell = body.crop((cx, cy, cx + CELL, cy + CELL))
            sheet.paste(paint_torso(cell, jersey, pads, cy < 64), (cx, cy))
        sheet.save(SHEET_DIR / f"{name}.png")
        write_anm2(tdir / "compact_body.anm2", CHAR_DIR / f"{name}.anm2",
                   f"costumes/{name}.png", "body1", "body0")

    legs = {
        "gridiron_legs_pants": (True, False),
        "gridiron_legs_cleats": (False, True),
        "gridiron_legs_pantscleats": (True, True),
    }
    for name, (pants, cleats) in legs.items():
        sheet = Image.new("RGBA", body.size, CLEAR)
        for cx, cy in cells(body):
            cell = body.crop((cx, cy, cx + CELL, cy + CELL))
            sheet.paste(paint_legs(cell, pants, cleats), (cx, cy))
        sheet.save(SHEET_DIR / f"{name}.png")
        write_anm2(tdir / "compact_body.anm2", CHAR_DIR / f"{name}.anm2",
                   f"costumes/{name}.png", "body0", "body0")
    print("costumes written")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
