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

from iconstyle import finish

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

# --- uniform colourways (picked in the settings menu: scripts/costumes.lua) ----------
# name: (dark, mid, light, gloss), plus the stripe/trim colour that goes with it.
# The first entry of each list is the default and keeps the un-suffixed file names.
TEAM_COLORS = {
    "red":    ([(118, 14, 22), (176, 28, 38), (218, 50, 58), (250, 150, 150)], (246, 246, 242)),
    "blue":   ([(25, 45, 120), (40, 75, 175), (70, 110, 210), (170, 200, 250)], (240, 200, 50)),
    "navy":   ([(14, 22, 52), (26, 38, 84), (46, 62, 120), (130, 150, 200)], (236, 236, 230)),
    "green":  ([(16, 70, 36), (28, 112, 56), (52, 152, 80), (160, 220, 170)], (240, 200, 50)),
    "orange": ([(150, 60, 10), (220, 100, 20), (245, 140, 50), (255, 210, 160)], (40, 40, 46)),
    "purple": ([(60, 25, 100), (95, 45, 150), (130, 75, 190), (200, 170, 240)], (240, 200, 50)),
    "gold":   ([(150, 110, 20), (205, 160, 40), (235, 195, 70), (255, 240, 170)], (40, 40, 46)),
    "black":  ([(22, 22, 28), (40, 40, 48), (64, 64, 76), (150, 150, 165)], (240, 200, 50)),
    "silver": ([(120, 124, 134), (170, 174, 184), (205, 208, 216), (245, 246, 250)], (26, 38, 84)),
    "white":  ([(170, 170, 165), (215, 215, 210), (242, 242, 238), (255, 255, 255)], (176, 28, 38)),
    "pink":   ([(176, 62, 112), (226, 104, 158), (246, 154, 194), (255, 214, 232)], (246, 246, 242)),
}
HELMET_COLORS = ["red", "blue", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink"]
JERSEY_COLORS = ["blue", "red", "navy", "green", "orange", "purple", "gold", "black", "silver", "white", "pink"]
PANTS_COLORS = ["white", "silver", "gold", "black", "navy", "red", "blue", "green", "orange", "purple", "pink"]


def rgba(c):
    return tuple(c) + (255,)


def icon_tone(c, floor=52):
    """Lift a very dark tone so the icon finishing pass doesn't read it as outline."""
    c = tuple(c)
    while 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] < floor:
        c = tuple(min(255, int(v * 1.2 + 6)) for v in c)
    return c


def use_helmet_color(name):
    global HELMET, HELMET_STRIPE, HELMET_STRIPE_SHADE
    tones, stripe = TEAM_COLORS[name]
    HELMET = [rgba(t) for t in tones]
    HELMET_STRIPE = rgba(stripe)
    HELMET_STRIPE_SHADE = (200, 200, 196, 255) if stripe == (246, 246, 242) else rgba(tuple(int(c * 0.82) for c in stripe))


def use_jersey_color(name):
    global JERSEY, JERSEY_TRIM
    tones, trim = TEAM_COLORS[name]
    JERSEY = [rgba(t) for t in tones[:3]]
    JERSEY_TRIM = rgba(trim)


def use_pants_color(name):
    global PANTS
    PANTS = [rgba(t) for t in TEAM_COLORS[name][0][:3]]


def suffix(name, default):
    return "" if name == default else "_" + name


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


def sleek(shell, mask, rows, view):
    """Reshape the round head into a modern shell: long, low crown with a raised
    center ridge, a squared brow, and jaw guards / back flare that kick outward."""
    grown = set(shell)

    def add(x, y):
        if 0 <= x < CELL and 0 <= y < CELL:
            grown.add((x, y))

    top = min(y for (_, y) in shell)
    if view == "right":
        for y in range(top + 2, top + 10):            # stretch the crown backward: longer, not taller
            if y in rows:
                add(rows[y][0] - 1, y)
        for y in (10, 11, 12):                        # visor shelf jutting out over the face
            if y in rows:
                for dx in (1, 2):
                    add(rows[y][1] + dx, y)
        for y in range(14, 24):                       # jaw guard sweeps forward toward the chin
            reach = 17 + (y - 14) * 4 // 9
            for x in range(12, reach + 1):
                add(x, y)
        for y in range(18, 23):                       # rear flare at the base of the shell
            if y in rows:
                add(rows[y][0] - 1, y)
    else:
        for y in range(top, top + 1):                 # raised center ridge instead of a dome
            for x in range(12, 20):
                add(x, y - 1)
        for y in (8, 9, 10, 11):                      # wider, squarer brow / temples
            if y in rows:
                add(rows[y][0] - 1, y)
                add(rows[y][1] + 1, y)
        flare = range(19, 24) if view == "down" else range(19, 25)
        for y in flare:                               # jaw guards / back flare kick outward
            if y in rows:
                lo, hi = rows[y]
                if (lo, y) in grown:
                    add(lo - 1, y)
                if (hi, y) in grown:
                    add(hi + 1, y)
    return grown


def roomy(src, grow=2):
    """Grow the head silhouette (top and sides, not the chin) so the helmet shell fits over
    big hair: used for the characters listed in scripts/costumes.lua (ROOMY_HELMET)."""
    s = src.load()
    mask = {(x, y) for y in range(CELL) for x in range(CELL) if s[x, y][3]}
    if not mask:
        return src
    chin = max(y for (_, y) in mask) - 3
    out = src.copy()
    o = out.load()
    for (x, y) in mask:
        for dy in range(-grow, grow + 1):
            for dx in range(-grow, grow + 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CELL and 0 <= ny < CELL and ny <= chin and dx * dx + dy * dy <= grow * grow + 1 \
                        and not o[nx, ny][3]:
                    o[nx, ny] = (227, 198, 197, 255)
    return out


def paint_helmet_roomy(src, view):
    return paint_helmet(roomy(src), view)


# where horns come up through the shell, per view (front/back: both corners; side: one)
HORN_HOLES = {"down": [(8, 4), (23, 4)], "up": [(8, 4), (23, 4)], "right": [(12, 3)]}


def paint_helmet_horns(src, view):
    """Roomy shell with reinforced horn holes, so horns come up *through* the helmet
    (Azazel, Lilith, Apollyon) instead of just poking out from under it."""
    out = paint_helmet(roomy(src), view)
    o = out.load()
    for cx, cy in HORN_HOLES[view]:
        hole = {(x, y) for y in range(cy - 2, cy + 2) for x in range(cx - 2, cx + 2)
                if ((x - cx + 0.5) / 2) ** 2 + ((y - cy + 0.5) / 1.6) ** 2 <= 1 and o[x, y][3]}
        ring = {p for p in outline_mask(hole, CELL, CELL) if o[p[0], p[1]][3]}
        for (x, y) in hole:
            o[x, y] = CLEAR                          # the horn shows through here
        for (x, y) in ring:
            o[x, y] = BUMPER[1] if y < cy else BUMPER[0]   # grommet: lit on top, shaded below
    return out


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
        # side view: the shell covers the brow, the back of the head and the jaw guard
        if y <= 12:
            return True
        if y <= 22:
            return x <= 17
        return x <= 19

    shell = {(x, y) for (x, y) in mask if in_shell(x, y)}
    grown = sleek(shell, mask, rows, view)
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
        # crown vents either side of the stripe
        for x, y in ((11, 4), (12, 4), (19, 4), (20, 4)):
            if (x, y) in grown and o[x, y] != OUTLINE:
                o[x, y] = OUTLINE
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
        # one clean panel seam from the visor back over the ear
        for x in range(13, 26):
            y = 9 if x >= 17 else 10
            if (x, y) in grown and o[x, y] not in (OUTLINE, HELMET_STRIPE):
                o[x, y] = HELMET[0]
        # ear hole with a screw below it (kept simple, like the real shell)
        for x, y in ((9, 15), (10, 15), (9, 16), (10, 16), (11, 16)):
            o[x, y] = OUTLINE
        o[10, 19] = BUMPER[1]
        # facemask: a thin one-pixel cage that protrudes past the face
        cage = [(18, 13), (19, 13), (20, 13), (21, 13), (22, 14), (23, 14), (24, 14), (25, 14),
                (26, 15), (27, 15), (28, 15)]                           # top bar, sloping down
        cage += [(29, y) for y in range(16, 22)]                        # front of the cage
        cage += [(x, 18) for x in range(18, 29)]                        # nose bar
        cage += [(x, 21) for x in range(18, 29)]                        # lower bar
        cage += [(22, y) for y in range(14, 22)]                        # connector bar
        cage += [(28, 22), (27, 23)] + [(x, 23) for x in range(19, 27)]  # chin bar back to the jaw
        for x, y in cage:
            o[x, y] = FACEMASK_SHADE
        for x, y in ((28, 15), (29, 16), (18, 13), (19, 13)):            # shine on the bends
            o[x, y] = FACEMASK
        for x, y in [(29, 15), (30, 16)] + [(30, y) for y in range(17, 22)] + [(29, 22), (28, 23)] \
                + [(x, 24) for x in range(19, 28)]:
            o[x, y] = OUTLINE

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


ALLPRO_GOLD = (236, 186, 58, 255)
ALLPRO_SHINE = (255, 240, 170, 255)


def paint_allpro(src, view):
    """All-Pro transformation: the eye black turns to gold war paint, with a glint at the corner."""
    out = paint_eye_black(src, view)
    o = out.load()
    for y in range(CELL):
        for x in range(CELL):
            p = o[x, y]
            if p[3]:
                o[x, y] = ALLPRO_SHINE if p == EYE_BLACK_SHINE else ALLPRO_GOLD
    if view == "down":
        for x, y in ((5, 19), (26, 19), (4, 18), (27, 18)):    # sparkle off the outer corners
            o[x, y] = ALLPRO_SHINE
    elif view == "right":
        o[21, 18] = ALLPRO_SHINE
        o[22, 17] = ALLPRO_SHINE
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
    # the collectible sprite is the costume's side view (default colours), so they always match
    use_helmet_color(HELMET_COLORS[0])
    finish(helmet_item_icon(head.crop((2 * CELL, 0, 3 * CELL, CELL)))).save(
        ROOT / "resources/gfx/items/collectibles/football_helmet.png")

    # coloured pedestal icons, swapped in by scripts/costumes.lua to match the uniform setting
    for color in HELMET_COLORS[1:]:
        use_helmet_color(color)
        HELMET[:] = [rgba(icon_tone(t[:3])) for t in HELMET]   # dark shells would turn to ink
        finish(helmet_item_icon(head.crop((2 * CELL, 0, 3 * CELL, CELL)))).save(
            ROOT / f"resources/gfx/items/collectibles/football_helmet_{color}.png")
    use_helmet_color(HELMET_COLORS[0])

    def head_sheet(name, painter, layer):
        sheet = Image.new("RGBA", head.size, CLEAR)
        for i, view, frame in head_frames(head):
            sheet.paste(painter(frame, view), (i * CELL, 0))
        sheet.save(SHEET_DIR / f"{name}.png")
        write_anm2(tdir / "compact_head.anm2", CHAR_DIR / f"{name}.anm2",
                   f"costumes/{name}.png", layer, "head0")

    def body_sheet(name, paint, layer):
        sheet = Image.new("RGBA", body.size, CLEAR)
        for cx, cy in cells(body):
            cell = body.crop((cx, cy, cx + CELL, cy + CELL))
            sheet.paste(paint(cell, cy), (cx, cy))
        sheet.save(SHEET_DIR / f"{name}.png")
        write_anm2(tdir / "compact_body.anm2", CHAR_DIR / f"{name}.anm2",
                   f"costumes/{name}.png", layer, "body0")

    head_sheet("gridiron_eyeblack", paint_eye_black, "head1")
    head_sheet("gridiron_allpro", paint_allpro, "head1")
    for color in HELMET_COLORS:
        use_helmet_color(color)
        head_sheet("gridiron_helmet" + suffix(color, HELMET_COLORS[0]), paint_helmet, "head5")
        head_sheet("gridiron_helmet_roomy" + suffix(color, HELMET_COLORS[0]), paint_helmet_roomy, "head5")
        head_sheet("gridiron_helmet_horns" + suffix(color, HELMET_COLORS[0]), paint_helmet_horns, "head5")

    # body rows 0-1 are the side view (right / left), rows 2-3 front/back
    body_sheet("gridiron_torso_pads", lambda cell, cy: paint_torso(cell, False, True, cy < 64), "body1")
    for color in JERSEY_COLORS:
        use_jersey_color(color)
        sfx = suffix(color, JERSEY_COLORS[0])
        body_sheet("gridiron_torso_jersey" + sfx, lambda cell, cy: paint_torso(cell, True, False, cy < 64), "body1")
        body_sheet("gridiron_torso_jerseypads" + sfx, lambda cell, cy: paint_torso(cell, True, True, cy < 64), "body1")

    body_sheet("gridiron_legs_cleats", lambda cell, cy: paint_legs(cell, False, True), "body0")
    for color in PANTS_COLORS:
        use_pants_color(color)
        sfx = suffix(color, PANTS_COLORS[0])
        body_sheet("gridiron_legs_pants" + sfx, lambda cell, cy: paint_legs(cell, True, False), "body0")
        body_sheet("gridiron_legs_pantscleats" + sfx, lambda cell, cy: paint_legs(cell, True, True), "body0")

    # every colourway is a null costume of its own (written for content/costumes2.xml)
    lines = ['<costumes anm2root="gfx/" version="1">',
             '    <!-- Generated by tools/make_costumes.py. All Gridiron costumes are null costumes applied',
             '         from scripts/costumes.lua, so they can be toggled, hidden per character and recoloured',
             '         (each uniform colour is its own costume). Pieces sharing a body layer come combined. -->']
    names = ["helmet" + suffix(c, HELMET_COLORS[0]) for c in HELMET_COLORS]
    names += ["helmet_roomy" + suffix(c, HELMET_COLORS[0]) for c in HELMET_COLORS]
    names += ["helmet_horns" + suffix(c, HELMET_COLORS[0]) for c in HELMET_COLORS] + ["eyeblack", "allpro", "torso_pads"]
    names += [n + suffix(c, JERSEY_COLORS[0]) for c in JERSEY_COLORS for n in ("torso_jersey", "torso_jerseypads")]
    names += ["legs_cleats"] + [n + suffix(c, PANTS_COLORS[0]) for c in PANTS_COLORS
                                for n in ("legs_pants", "legs_pantscleats")]
    for n in names:
        prio = ' priority="99"' if n.startswith("helmet") else ""
        lines.append(f'    <costume anm2path="characters/gridiron_{n}.anm2" type="none"{prio} />')
    lines.append("</costumes>")
    (ROOT / "content/costumes2.xml").write_text("\n".join(lines) + "\n")
    print("costumes written")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
