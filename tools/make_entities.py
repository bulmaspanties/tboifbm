"""Draw Gridiron's familiars / enemies / boss and write their .anm2 files.

Each entity is a horizontal strip of square frames plus a list of animations
(name -> frame indices). Frames are pixel grids built with the shape helpers
from make_sprites.py, so everything shares one palette.

    python3 tools/make_entities.py      (from the repo root; needs Pillow)
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from make_sprites import PALETTE, blank, ellipse, outline, put, rect, render_rows, rows_of  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
GFX = ROOT / "resources/gfx"

SKIN = [("s", (227, 198, 197, 255)), ("x", (207, 156, 155, 255)), ("z", (185, 115, 113, 255))]
for key, col in SKIN:
    assert PALETTE.get(key, col) == col, f"palette key {key} already used"
    PALETTE[key] = col
PALETTE.setdefault("e", (24, 16, 16, 255))     # eyes
PALETTE.setdefault("m", (150, 150, 158, 255))  # metal
# Isaac-style monster flesh (gaper grey-pink), blood, fly bits
for key, col in {"p": (95, 45, 150, 255), "V": (62, 26, 104, 255), "X": (138, 84, 196, 255),
                 "j": (255, 255, 255, 200), "J": (214, 228, 242, 110),
                 "q": (204, 178, 170, 255), "Q": (160, 128, 122, 255), "h": (112, 76, 72, 255),
                 "i": (132, 10, 16, 255), "l": (206, 222, 236, 255), "M": (66, 58, 62, 255)}.items():
    assert PALETTE.get(key, col) == col, f"palette key {key} already used"
    PALETTE[key] = col


def gaper_face(g, cx, cy, r=6, mouth="o", blood=True, angry=False):
    """Isaac's basic humanoid face: a smooth, bulbous pale head, giant solid black oval
    eyes with a white glint in the top corner, and something gross (gaping mouth, blood)."""
    ellipse(g, cx, cy, r, r * 0.95, "q")
    ellipse(g, cx + 0.5, cy + r * 0.45, r * 0.85, r * 0.45, "Q")      # sagging lower face in shadow
    ellipse(g, cx - r * 0.25, cy - r * 0.35, r * 0.45, r * 0.3, "q")
    ex = r * 0.42
    for sx in (-1, 1):
        ellipse(g, cx + sx * ex, cy - 0.3, r * 0.27, r * 0.36, "e")
        put(g, [(round(cx + sx * ex - r * 0.12), round(cy - r * 0.25))], "W")   # glint
        if angry:
            put(g, [(round(cx + sx * ex - r * 0.3), round(cy - r * 0.55)), (round(cx + sx * ex), round(cy - r * 0.45))], "h")
    my = cy + r * 0.62
    if mouth == "o":                                                  # gaping / screaming
        ellipse(g, cx, my, r * 0.24, r * 0.22, "e")
    elif mouth == "wide":                                             # stretched way too wide
        ellipse(g, cx, my, r * 0.55, r * 0.22, "e")
    elif mouth == "grimace":                                          # clenched teeth
        rect(g, round(cx - r * 0.45), round(my) - 1, round(cx + r * 0.45), round(my), "e")
        for x in range(round(cx - r * 0.4), round(cx + r * 0.45), 2):
            put(g, [(x, round(my) - 1)], "W")
    if blood:                                                         # tears of blood from one eye
        bx = round(cx - ex)
        put(g, [(bx, round(cy + r * 0.12)), (bx, round(cy + r * 0.28)), (bx - 1, round(cy + r * 0.42))], "i")


# --- shared figure pieces -------------------------------------------------------
def head(g, cx, cy, r=6.5):
    """Isaac-style big round head with two eyes."""
    ellipse(g, cx, cy, r, r * 0.92, "s")
    ellipse(g, cx + 1, cy + 2, r * 0.75, r * 0.55, "s")
    rect(g, int(cx - 3), int(cy), int(cx - 2), int(cy + 1), "e")
    rect(g, int(cx + 2), int(cy), int(cx + 3), int(cy + 1), "e")


def body(g, cx, top, shirt, legs_offset=0):
    rect(g, cx - 3, top, cx + 3, top + 4, shirt)
    rect(g, cx - 3, top + 5, cx - 1, top + 7 + legs_offset, "x")
    rect(g, cx + 1, top + 5, cx + 3, top + 7 - legs_offset, "x")


# --- Football uniforms ---------------------------------------------------------------
# Players are drawn with placeholder kit keys, so one drawing renders in any team's colours:
#   ! jersey   @ jersey shade   # pants   $ pants shade   % trim (stripes, numbers)
#   ^ helmet   ~ helmet shade   * captain's patch (invisible unless the kit is a captain's)
from make_costumes import TEAM_COLORS  # noqa: E402

KIT_KEYS = "!@#$%^~*&"
CAPTAIN_GOLD = (240, 200, 50)


def kit(jersey, pants="white", helmet=None, captain=False):
    """Palette for the kit keys. A captain gets gold trim and the gold 'C' patch."""
    j, _ = TEAM_COLORS[jersey]
    p, _ = TEAM_COLORS[pants]
    h, _ = TEAM_COLORS[helmet or jersey]
    trim = TEAM_COLORS[jersey][1]
    if captain:
        trim = CAPTAIN_GOLD if jersey != "gold" else (246, 246, 242)
    return {"!": j[1] + (255,), "@": j[0] + (255,), "&": j[2] + (255,), "#": p[2] + (255,), "$": p[1] + (255,),
            "%": trim + (255,), "^": h[1] + (255,), "~": h[0] + (255,),
            "*": (CAPTAIN_GOLD if captain else j[1]) + (255,)}


def uniform(g, cx, sy, wy, hw, step=0, legs=True, fy=None, sleeves=True, number=True):
    """A suited-up football body: shoulder pads under the jersey (the shoulders bulge and the
    pad edge shows), short sleeves with stripes, a numbered chest, a belt, padded pants with a
    side stripe, high socks and black cleats.
      cx: centre x   sy: top of the shoulder pads   wy: waist row   hw: half-width at the pads"""
    cx = round(cx)
    # torso under the pads, tapering a little to the waist
    rect(g, cx - hw + 3, sy + 3, cx + hw - 3, wy, "!")
    rect(g, cx + hw - 4, sy + 4, cx + hw - 3, wy, "@")                     # coloured shade, right side
    rect(g, cx - hw + 3, wy, cx + hw - 3, wy, "@")
    # the pads: a broad dome with a cap on each shoulder
    ellipse(g, cx, sy + 2.5, hw, 3, "!")
    for sx in (-1, 1):
        ellipse(g, cx + sx * (hw - 2.6), sy + 2, 2.8, 2.3, "!")
        put(g, [(cx + sx * (hw - 1), sy + 2), (cx + sx * (hw - 1), sy + 3)], "%")   # sleeve stripe
        put(g, [(cx + sx * (hw - 3) - 1, sy + 1), (cx + sx * (hw - 3), sy + 1)], "&")   # light on the pad cap
    rect(g, cx - hw + 1, sy + 5, cx - hw + 3, sy + 5, "@")                 # pad edge under the jersey
    rect(g, cx + hw - 3, sy + 5, cx + hw - 1, sy + 5, "@")
    put(g, [(cx - 1, sy + 1), (cx, sy + 1), (cx + 1, sy + 1)], "@")        # collar
    if sleeves:                                                            # forearms out of the sleeves
        for sx in (-1, 1):
            put(g, [(cx + sx * hw, sy + 5), (cx + sx * hw, sy + 6)], "q")
            put(g, [(cx + sx * hw, sy + 7)], "Q")
    if number and wy - sy >= 7:                                            # a chunky chest number
        ny = sy + 4
        put(g, [(cx - 1, ny), (cx, ny), (cx, ny + 1), (cx, ny + 2), (cx - 1, ny + 2), (cx + 1, ny + 2)], "%")
    put(g, [(cx - hw + 4, sy + 4), (cx - hw + 5, sy + 4), (cx - hw + 4, sy + 5), (cx - hw + 4, sy + 6),
            (cx - hw + 5, sy + 6)], "*")                                    # the captain's "C"
    rect(g, cx - hw + 3, wy + 1, cx + hw - 3, wy + 1, "k")                 # belt
    if not legs:
        return
    fy = fy if fy is not None else wy + 7
    ky = wy + 2 + (fy - wy - 2) // 2                                       # knee
    for side, lift in ((-1, step), (1, -step)):
        x0, x1 = (cx - hw + 3, cx - 1) if side < 0 else (cx + 1, cx + hw - 3)
        foot = fy - max(0, lift)
        rect(g, x0, wy + 2, x1, ky, "#")                                   # padded pants
        put(g, [(x0 if side < 0 else x1, y) for y in range(wy + 2, ky + 1)], "%")   # side stripe
        put(g, [(x1 if side < 0 else x0, ky)], "$")
        sx0, sx1 = (x0 + 1, x1) if side < 0 else (x0, x1 - 1)
        rect(g, sx0, ky + 1, sx1, foot - 1, "!")                           # high socks
        rect(g, sx0 - (1 if side < 0 else 0), foot, sx1 + (0 if side < 0 else 1), foot, "k")   # cleats


# --- Cheerleader: Idle (bob) and Cheer (pom-poms up) ------------------------------
def cheerleader(frame):
    g = blank()
    bob = frame % 2
    cheering = frame >= 2
    cx = 16
    body(g, cx, 18 + bob, "B")
    rect(g, cx - 4, 22 + bob, cx + 4, 23 + bob, "W")          # skirt
    head(g, cx, 11 + bob)
    rect(g, cx - 6, 5 + bob, cx + 6, 7 + bob, "y")           # hair
    ellipse(g, cx - 7, 9 + bob, 1.6, 2.5, "y")               # pigtails
    ellipse(g, cx + 7, 9 + bob, 1.6, 2.5, "y")
    if cheering:
        up = 2 if frame == 3 else 0
        ellipse(g, cx - 8, 9 - up, 3.2, 3.2, "Y")             # pom-poms high
        ellipse(g, cx + 8, 9 - up, 3.2, 3.2, "Y")
        put(g, [(cx - 7, 10 - up), (cx + 7, 10 - up), (cx - 9, 8 - up), (cx + 9, 8 - up)], "B")
    else:
        ellipse(g, cx - 6, 21 + bob, 3, 3, "Y")               # pom-poms low
        ellipse(g, cx + 6, 21 + bob, 3, 3, "Y")
        put(g, [(cx - 5, 22 + bob), (cx + 7, 20 + bob)], "B")
    return rows_of(outline(g))


# --- Water Boy: Idle (bob) and Drop (bottle raised) ----------------------------
def water_boy(frame):
    g = blank()
    bob = frame % 2
    pouring = frame >= 2
    cx = 15
    body(g, cx, 18 + bob, "W")
    head(g, cx, 11 + bob)
    rect(g, cx - 6, 4 + bob, cx + 5, 7 + bob, "B")           # cap
    rect(g, cx + 2, 7 + bob, cx + 8, 7 + bob, "b")           # brim
    # water carrier (crate with two bottles)
    rect(g, 20, 19 + bob, 27, 25 + bob, "R")
    rect(g, 20, 19 + bob, 27, 19 + bob, "r")
    if pouring:
        rect(g, 22, 10, 24, 17, "C")                         # bottle raised high
        rect(g, 22, 9, 24, 9, "W")
        put(g, [(23, 7), (23, 5)], "C")                      # splash
    else:
        rect(g, 21, 15 + bob, 22, 18 + bob, "C")
        rect(g, 25, 15 + bob, 26, 18 + bob, "C")
        put(g, [(21, 14 + bob), (25, 14 + bob)], "W")
    return rows_of(outline(g))


# --- Tackling Dummy: Idle and Hit (squash) --------------------------------------
def tackling_dummy(frame):
    g = blank()
    squash = 2 if frame == 1 else 0
    lean = 1 if frame == 1 else 0
    rect(g, 6, 25, 25, 27, "m")                               # sled base
    rect(g, 4, 27, 27, 27, "g")
    rect(g, 11 + lean, 6 + squash, 20 + lean, 25, "R")        # pad
    ellipse(g, 15.5 + lean, 6 + squash, 4.5, 2, "R")
    rect(g, 11 + lean, 6 + squash, 12 + lean, 25, "r")
    rect(g, 11 + lean, 14 + squash // 2, 20 + lean, 16 + squash // 2, "W")  # stripe
    rect(g, 18 + lean, 7 + squash, 19 + lean, 13, "H")        # shine
    return rows_of(outline(g))


# --- Mascot: Walk (waddle) and Shoot (t-shirt cannon) ---------------------------
def mascot(frame):
    """A costume falling apart: one googly eye hanging loose, a torn seam leaking blood."""
    g = blank()
    step = frame % 2
    shooting = frame >= 2
    cx = 12
    ellipse(g, cx, 21, 6.5, 5, "Y")                            # furry body, sagging
    ellipse(g, cx, 24, 5.5, 2, "y")
    rect(g, cx - 4, 26, cx - 2, 27 - step, "O")                # big orange feet
    rect(g, cx + 2, 26, cx + 4, 26 + step, "O")
    ellipse(g, cx, 11, 7.5, 7, "Y")                            # mascot head
    ellipse(g, cx + 1, 14, 6, 3, "y")
    ellipse(g, cx - 3, 10, 2.4, 2.8, "W")                      # googly eye
    put(g, [(cx - 3, 11)], "e")
    ellipse(g, cx + 4, 14, 2, 2.2, "W")                        # the other one, hanging by a thread
    put(g, [(cx + 4, 15), (cx + 3, 11), (cx + 3, 12)], "e")
    rect(g, cx - 2, 13, cx + 1, 14, "O")                       # beak
    rect(g, cx - 6, 3, cx + 6, 4, "B")                         # team headband
    put(g, [(cx - 5, 17), (cx - 4, 18), (cx - 3, 17), (cx - 2, 18)], "q")   # torn seam: flesh inside
    put(g, [(cx - 4, 19), (cx - 4, 20)], "i")
    kick = -1 if shooting and frame == 2 else 0
    rect(g, cx + 4 + kick, 18, cx + 13 + kick, 21, "m")        # t-shirt cannon
    rect(g, cx + 12 + kick, 17, cx + 14 + kick, 22, "N")
    if frame == 2:
        put(g, [(cx + 16, 18), (cx + 17, 20), (cx + 16, 22), (cx + 18, 19)], "W")   # muzzle puff
    return rows_of(outline(g))


def ref_shirt(g, x0, y0, x1, y1):
    rect(g, x0, y0, x1, y1, "W")
    for x in range(x0, x1 + 1, 2):
        rect(g, x, y0, x, y1, "n")                              # dark grey stripes, not ink


def unhinged_face(g, cx, cy, r=6, flag=False):
    """A referee who's seen too much: huge wide-open eyes with tiny frantic pupils,
    and a mouth stretched way too wide (sometimes with the flag coming out of it)."""
    ellipse(g, cx, cy, r, r * 0.95, "q")
    ellipse(g, cx + 0.5, cy + r * 0.45, r * 0.85, r * 0.45, "Q")
    for sx in (-1, 1):
        ex = cx + sx * r * 0.42
        ellipse(g, ex, cy - 0.8, r * 0.33, r * 0.38, "W")
        put(g, [(round(ex + sx * 0.5), round(cy - 0.5))], "e")   # pinprick pupils
        put(g, [(round(ex - 1), round(cy - r * 0.62)), (round(ex), round(cy - r * 0.68)),
                (round(ex + 1), round(cy - r * 0.62))], "h")    # brows shot up
    ellipse(g, cx, cy + r * 0.62, r * 0.6, r * 0.24, "e")       # mouth stretched too wide
    put(g, [(round(cx - r * 0.45), round(cy + r * 0.55)), (round(cx + r * 0.45), round(cy + r * 0.55))], "W")
    if flag:
        rect(g, round(cx + 1), round(cy + r * 0.62), round(cx + 5), round(cy + r * 0.62) + 3, "Y")
        put(g, [(round(cx + 2), round(cy + r * 0.62) + 1)], "y")


# --- Referee: Walk and Throw (flag up) -------------------------------------------
def referee(frame):
    g = blank()
    step = frame % 2
    throwing = frame >= 2
    cx = 15
    ref_shirt(g, cx - 4, 18, cx + 4, 23)
    rect(g, cx - 3, 24, cx - 1, 27 - step, "n")                # black pants (dark grey)
    rect(g, cx + 1, 24, cx + 3, 26 + step, "n")
    unhinged_face(g, cx, 12, 6.2, flag=frame == 3)
    rect(g, cx - 6, 5, cx + 6, 6, "n")                         # cap
    rect(g, cx - 7, 6, cx + 2, 6, "N")
    if throwing:
        rect(g, cx + 5, 6 if frame == 3 else 9, cx + 6, 17, "Q")   # arm up
        rect(g, cx + 7, 3 if frame == 3 else 6, cx + 11, 7 if frame == 3 else 10, "Y")  # flag
    else:
        rect(g, cx + 5, 19, cx + 6, 22, "Q")
        rect(g, cx + 6, 21, cx + 8, 23, "Y")                   # flag tucked in the belt
    return rows_of(outline(g))


# --- Lineman: Charger-style hunch, helmet pulled low over giant eyes ------------------
def low_helmet(g, cx, cy, r, shell, shade, stripe="W", mask=True, ring=False):
    """A helmet sitting low: only the giant eyes and a grimace show through the gap.
    ring: a dark inner line around the shell, so it reads against a jersey of the same colour."""
    if ring:
        ellipse(g, cx, cy - 0.5, r + 2, r + 1.2, "K")
    ellipse(g, cx, cy - 1, r + 1, r, shell)
    ellipse(g, cx + 1, cy + 1, r, r * 0.6, shade)               # coloured shading, not ink
    rect(g, round(cx - r * 0.75), round(cy), round(cx + r * 0.75), round(cy + r * 0.75), "q")   # face gap
    for sx in (-1, 1):
        ex = cx + sx * r * 0.4
        ellipse(g, ex, cy + 1, r * 0.26, r * 0.32, "e")
        put(g, [(round(ex - 1), round(cy))], "W")
    rect(g, round(cx - r * 0.5), round(cy + r * 0.62), round(cx + r * 0.5), round(cy + r * 0.62), "e")   # grimace
    for x in range(round(cx - r * 0.45), round(cx + r * 0.5), 2):
        put(g, [(x, round(cy + r * 0.62))], "W")
    if mask:
        rect(g, round(cx - r * 0.8), round(cy + r * 0.4), round(cx + r * 0.8), round(cy + r * 0.4), "G")
    put(g, [(round(cx), round(cy - r)), (round(cx), round(cy - r) + 1)], stripe)


def lineman(frame):
    """A hulking offensive lineman in full kit, head sunk between his pads."""
    g = blank()
    pose = ["walk", "walk", "dig", "charge", "charge"][frame]
    step = frame % 2 if pose != "dig" else 0
    down = 2 if pose == "dig" else 0
    lean = 2 if pose == "charge" else 0
    uniform(g, 16 + lean, 13 + down, 21 + down, 10, step=step, fy=30)
    put(g, [(9 + lean, 22 + down), (21 + lean, 18 + down)], "i")           # blood on the jersey
    low_helmet(g, 16 + lean, 13 + down, 5.5, "^", "~", stripe="@", ring=True)   # head sunk between the pads
    put(g, [(14 + lean, 7 + down), (13 + lean, 8 + down)], "~")            # crack in the shell
    if pose == "charge":
        put(g, [(16 + lean, 20 + down), (17 + lean, 21 + down)], "i")      # drool flying
    if pose == "dig":
        put(g, [(4, 29), (6, 30), (26, 30), (28, 29), (5, 27)], "d")       # dirt clods
    return rows_of(outline(g))


# --- Blitzer: an Attack Fly with a leather skullcap stretched over its head ------------
WINGS = {"j": (255, 255, 255, 200), "J": (214, 228, 242, 110)}


def add_wings(rows, wings):
    """Overlay translucent wings with a soft white edge after the outline pass."""
    g = [list(r) for r in rows]
    for cx, cy, rx, ry in wings:
        for y in range(32):
            for x in range(32):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0 and g[y][x] == ".":
                    g[y][x] = "j" if d > 0.55 else "J"
    return ["".join(r) for r in g]


def blitzer(frame):
    g = blank()
    dive = frame == 2
    ellipse(g, 16, 19, 5.5 if not dive else 4.5, 4.5 if not dive else 6, "M")   # fat black body
    # a too-small jersey pulled over the body, shoulder pads bulging at the top
    ellipse(g, 16, 18.5, 5 if not dive else 4, 3.4 if not dive else 4.6, "!")
    ellipse(g, 17.5, 20, 3, 2.2 if not dive else 3.2, "@")
    for sx in (-1, 1):
        ellipse(g, 16 + sx * 4, 16.5, 2, 1.5, "!")
        put(g, [(16 + sx * 5, 16)], "%")                                       # sleeve stripe
    put(g, [(16, 18), (16, 19), (16, 20)], "%")                                 # number 1
    put(g, [(13, 18), (13, 19), (14, 18)], "*")                                 # captain's patch
    put(g, [(14, 23), (16, 23 + (1 if dive else 0)), (18, 23)], "h")             # belly poking out
    ellipse(g, 16, 14, 5.5, 4.2, "M")                                           # head
    for sx in (-1, 1):                                                          # huge glassy compound eyes
        ellipse(g, 16 + sx * 2.6, 15, 2.6, 2.8, "e")
        put(g, [(round(16 + sx * 2.6 - 1), 14)], "W")
    ellipse(g, 16, 10.5, 4.2, 2.2, "f")                                         # leather skullcap
    rect(g, 12, 11, 20, 11, "F")                                                # stretched rim
    put(g, [(16, 9), (16, 10)], "E")                                            # stitching
    put(g, [(13, 12), (19, 12)], "f")                                           # strap stretched over the eyes
    put(g, [(15, 18), (17, 18)], "i")                                           # little proboscis drip
    rows = rows_of(outline(g))
    if dive:
        return add_wings(rows, [(10, 12, 3.5, 2), (22, 12, 3.5, 2)])
    up = frame == 0
    return add_wings(rows, [(8, 10 if up else 15, 4.8, 2.8), (24, 10 if up else 15, 4.8, 2.8)])


# --- Punter: a Gaper ragdoll with one floppy kicking leg ---------------------------
def punter(frame):
    """A gaper ragdoll suited up as the punter, with one floppy kicking leg."""
    g = blank()
    kick = frame - 1 if frame >= 2 else 0                           # 0 idle, 1 wind, 2 kick
    bob = frame % 2 if frame < 2 else 0
    uniform(g, 15, 15 + bob, 22, 7, legs=False)
    # planted leg: pants, sock, cleat
    rect(g, 11, 24, 14, 25, "#")
    put(g, [(11, 24), (11, 25)], "%")
    rect(g, 12, 26, 13, 27, "!")
    rect(g, 10, 28, 13, 28, "k")
    if kick == 0:
        rect(g, 16, 24, 19, 25, "#")
        put(g, [(19, 24), (19, 25)], "%")
        rect(g, 16, 26, 17, 27, "!")
        rect(g, 16, 28, 19, 28, "k")
    elif kick == 1:                                                 # leg flung back
        rect(g, 15, 23, 18, 24, "#")
        put(g, [(8, 22), (9, 22), (10, 23), (11, 23)], "!")
        put(g, [(12, 23), (13, 23), (14, 23)], "#")
        rect(g, 5, 21, 7, 22, "k")
    else:                                                           # leg whipped up, way too high
        rect(g, 16, 22, 19, 24, "#")
        put(g, [(20, 21), (21, 20), (21, 19), (22, 18), (23, 17), (23, 16)], "!")
        rect(g, 23, 13, 26, 15, "k")
    gaper_face(g, 15, 10 + bob, 7.2, mouth="o")                     # bulbous gaper head, screaming
    return rows_of(outline(g))


# --- Huddle: little Chargers in orange helmets, hunched together ---------------------
def huddle(frame):
    """Little chargers in full kit, hunched over and running in a pack."""
    g = blank()
    step = frame % 2
    running = frame >= 2
    uniform(g, 16, 16, 22, 7, step=step, fy=28, number=False)
    low_helmet(g, 16, 14, 4.6, "^", "~", stripe="%", mask=False, ring=True)
    if running:
        put(g, [(16, 19), (16, 20)], "i")                           # drool
        put(g, [(5, 14), (4, 16), (27, 14), (28, 16)], "v")        # speed lines
    return rows_of(outline(g))


# --- Gatorade Cooler: a saggy orange tub on fleshy legs, one eye under the lid ------------
def cooler(frame):
    g = blank()
    wob = frame % 2
    ox = wob
    # tub with rounded, sagging corners (wider at the bottom, like it's slumping)
    rect(g, 8 + ox, 11, 23 + ox, 22, "O")
    ellipse(g, 15.5 + ox, 22.5, 9, 3.2, "O")                        # sagging belly
    ellipse(g, 9 + ox, 11.5, 1.5, 1.5, "O")
    ellipse(g, 22 + ox, 11.5, 1.5, 1.5, "O")
    ellipse(g, 11 + ox, 17, 2, 6, "P")                              # highlight
    ellipse(g, 21.5 + ox, 18, 1.6, 6.5, "o")                        # coloured shade, not ink
    ellipse(g, 15.5 + ox, 24.5, 7.5, 1.4, "o")
    ellipse(g, 15.5 + ox, 8.5, 9, 2.4, "W")                         # lid, knocked crooked
    ellipse(g, 15.5 + ox, 9.4, 8, 1.2, "w")
    rect(g, 12 + ox, 5, 19 + ox, 5, "v")                            # handle
    put(g, [(12 + ox, 6), (19 + ox, 6)], "v")
    ellipse(g, 15.5 + ox, 12.5, 3.2, 1.9, "q")                      # the eye peeking out
    ellipse(g, 15.5 + ox, 12.5, 1.6, 1.6, "e")
    put(g, [(15 + ox, 12)], "W")
    put(g, [(13 + ox, 13), (18 + ox, 13)], "i")                     # bloodshot
    rect(g, 10 + ox, 16, 20 + ox, 18, "W")                          # label
    put(g, [(12 + ox, 17), (14 + ox, 17), (16 + ox, 17), (18 + ox, 17)], "o")
    rect(g, 23 + ox, 19, 25 + ox, 20, "m")                          # dirty worn spigot
    put(g, [(25 + ox, 21), (24 + ox, 21)], "d")
    put(g, [(25 + ox, 22), (25 + ox, 24)], "O")                     # orange drip
    put(g, [(7 + ox, 13), (6 + ox, 15)], "P")                       # slosh over the rim
    put(g, [(10, 26), (10, 27), (9, 28 - wob)], "Q")                # fleshy legs
    put(g, [(21, 26), (21, 27), (22, 27 + wob)], "Q")
    return rows_of(outline(g))


# --- Chain Gang: unhinged zombie refs with a shackle on one wrist --------------------------
def chain_ref(frame):
    g = blank()
    step = frame % 2
    ref_shirt(g, 11, 18, 19, 24)
    rect(g, 12, 25, 14, 28 - step, "n")
    rect(g, 16, 25, 18, 27 + step, "n")
    put(g, [(20, 19), (20, 20), (21, 21), (21, 22)], "Q")           # arm
    rect(g, 20, 23, 22, 25, "m")                                    # shackle
    put(g, [(21, 26)], "i")                                         # raw wrist
    unhinged_face(g, 15, 12, 6.2)
    rect(g, 9, 5, 21, 6, "n")                                       # cap
    rect(g, 8, 6, 17, 6, "N")
    return rows_of(outline(g))


def chain_link(_):
    g = blank(8)
    ellipse(g, 3.5, 3.5, 3, 2.2, "m")
    ellipse(g, 3.5, 3.5, 1.4, 0.9, ".")
    return rows_of(outline(g))


# --- Sacker: tunnels like a Round Worm; pops up in a mud-caked helmet ---------------------
def dirt_hole(g, cx, cy, w, h, jag):
    """A jagged clumpy dirt mound with a dark hole in the middle."""
    ellipse(g, cx, cy, w, h, "d")
    for i, (dx, dy) in enumerate(((-w + 1, -1), (-w + 3, -h), (-2, -h - 1), (2, -h), (w - 3, -h + 0.5),
                                  (w - 1, -1), (-w + 2, h - 1), (w - 2, h - 1))):
        ellipse(g, cx + dx, cy + dy + (jag if i % 2 else 0), 1.6, 1.3, "d")   # clumps
    ellipse(g, cx, cy - 0.5, w * 0.55, h * 0.45, "h")              # dark inner shadow
    ellipse(g, cx, cy - 0.5, w * 0.3, h * 0.22, "e")


def sacker(frame):
    g = blank()
    state = ["mound", "mound", "rise", "rise", "up", "up"][frame]
    if state == "mound":
        dirt_hole(g, 16, 24, 9, 3.6, frame)
        put(g, [(9, 21 - frame), (16, 20 - frame), (22, 21 - frame)], "T")   # torn grass
        return rows_of(outline(g))
    if state == "rise":
        shake = frame - 2
        dirt_hole(g, 16, 25, 10, 3.8, 1)
        ellipse(g, 16 + shake, 19, 6, 5, "^")                       # mud-caked helmet breaking through
        ellipse(g, 17 + shake, 20.5, 5, 3, "~")
        put(g, [(16 + shake, 14), (16 + shake, 15)], "%")
        put(g, [(14 + shake, 16), (18 + shake, 17), (13 + shake, 19)], "d")
        put(g, [(6, 20), (26, 20), (8 + shake, 15), (24 - shake, 14), (11, 12), (21, 12)], "d")   # dirt spray
        return rows_of(outline(g))
    lift = frame - 4
    dirt_hole(g, 16, 26, 10, 3.4, 0)
    uniform(g, 16, 13 - lift, 22 - lift, 8, legs=False, sleeves=False)   # suited up, climbing out
    put(g, [(10, 18 - lift), (19, 16 - lift), (21, 20 - lift), (13, 21 - lift)], "d")   # caked in mud
    put(g, [(6, 15 - lift), (7, 16 - lift), (8, 17 - lift)], "q")      # claw arms up
    put(g, [(26, 15 - lift), (25, 16 - lift), (24, 17 - lift)], "q")
    put(g, [(5, 14 - lift), (7, 14 - lift), (25, 14 - lift), (27, 14 - lift)], "W")   # claws
    low_helmet(g, 16, 12 - lift, 5.6, "^", "~", stripe="%", mask=False, ring=True)
    put(g, [(13, 7 - lift), (18, 8 - lift), (20, 10 - lift), (12, 10 - lift), (15, 6 - lift)], "d")   # heavy with mud
    put(g, [(16, 18 - lift), (16, 19 - lift)], "i")
    dirt_hole_front = [(x, 25) for x in range(8, 25)]                  # the lip of the hole in front
    put(g, dirt_hole_front, "d")
    return rows_of(outline(g))


# --- The Coach (miniboss, 48x48): Duke-of-Flies sag, no neck, bellowing ----------------
def coach(frame):
    g = blank(48)
    bob = frame % 2
    yelling = frame >= 2
    rect(g, 16, 40, 21, 44, "E")                                    # stubby khaki legs
    rect(g, 27, 40, 32, 44 - bob, "E")
    rect(g, 15, 44, 22, 45, "n")
    rect(g, 26, 44 - bob, 33, 45 - bob, "n")
    ellipse(g, 24, 29 + bob, 17, 12, "B")                           # wide, sagging body
    ellipse(g, 24, 33 + bob, 15, 7, "b")                            # bottom-heavy shade (navy, not ink)
    rect(g, 10, 37 + bob, 38, 38 + bob, "d")                        # belt, peeking out at the sides
    ellipse(g, 24, 36 + bob, 10, 6.5, "B")                          # the gut, hanging over the belt
    ellipse(g, 22, 34 + bob, 6, 3.5, "L")
    put(g, [(24, 39 + bob), (25, 39 + bob)], "q")                   # belly showing under the shirt
    ellipse(g, 8, 30 + bob, 3, 5, "x")                              # meaty arm
    ellipse(g, 24, 15 + bob, 11, 9, "x")                            # head sunk straight into the chest
    ellipse(g, 24, 19 + bob, 9.5, 5, "z")                           # flushed jowls
    for sx in (-1, 1):                                              # beady black eyes
        ellipse(g, 24 + sx * 4.5, 13 + bob, 1.7, 2, "e")
        put(g, [(24 + sx * 4.5 - 1, 12 + bob)], "W")
        rect(g, 24 + sx * 4.5 - 2, 10 + bob, 24 + sx * 4.5 + 2, 10 + bob, "h")   # furious brows
    if yelling:                                                     # bellowing, whistle in sharp teeth
        ellipse(g, 24, 19.5 + bob, 4.5, 3.4, "e")
        ellipse(g, 24, 21 + bob, 2.5, 1.4, "i")
        for x in (21, 23, 25, 27):
            put(g, [(x, 17 + bob)], "W")
            put(g, [(x, 22 + bob)], "W")
        rect(g, 23, 18 + bob, 26, 19 + bob, "m")
    else:
        rect(g, 20, 19 + bob, 28, 20 + bob, "e")
        for x in (21, 24, 27):
            put(g, [(x, 19 + bob)], "W")
        rect(g, 24, 20 + bob, 26, 20 + bob, "m")
    rect(g, 13, 4 + bob, 35, 8 + bob, "N")                          # cap
    rect(g, 22, 8 + bob, 40, 9 + bob, "N")
    put(g, [(23, 5 + bob), (24, 5 + bob), (23, 6 + bob), (24, 6 + bob)], "R")
    rect(g, 12, 9 + bob, 13, 17 + bob, "n")                         # headset
    rect(g, 13, 17 + bob, 17, 17 + bob, "n")
    up = 6 if yelling else 0
    rect(g, 37, 26 - up + bob, 40, 33 - up + bob, "x")              # clipboard arm
    rect(g, 37, 15 - up + bob, 46, 27 - up + bob, "d")
    rect(g, 38, 17 - up + bob, 45, 26 - up + bob, "W")
    put(g, [(39, 19 - up + bob), (41, 21 - up + bob), (43, 23 - up + bob), (40, 24 - up + bob)], "R")
    put(g, [(42, 19 - up + bob), (44, 20 - up + bob)], "B")
    put(g, [(30, 22 + bob), (31, 24 + bob), (30, 26 + bob)], "i")   # sweat... or worse
    return rows_of(outline(g))


# --- The Franchise (final boss, 80x80): Mega Fatty bulk in a #1 jersey, one monstrous arm --------
def franchise(pose, frame=0):
    g = blank(80)
    bob = frame % 2
    rage = pose.startswith("rage")
    squash = 4 if pose == "slam" else 0
    by = 52 + bob + squash
    # gold game pants (purple side stripe), purple socks and cleats
    for x0, x1 in ((25, 38), (42, 55)):
        rect(g, x0, 64, x1, 73, "A")
        rect(g, x1 - 3 if x0 < 40 else x0, 64, x1 if x0 < 40 else x0 + 3, 73, "a")   # inner shade
        rect(g, x0 if x0 < 40 else x1, 64, x0 if x0 < 40 else x1, 73, "p")            # side stripe
        rect(g, x0 + 3, 74, x1 - 3, 76, "p")
        rect(g, x0 + 3, 75, x1 - 3, 75, "W")                          # sock stripe
        rect(g, x0 + 1, 77, x1 - 2, 78, "n")
    # the gut hanging out under the jersey, over the waistband
    ellipse(g, 40, by + 11, 17, 7, "q")
    ellipse(g, 43, by + 14, 12, 4, "Q")
    put(g, [(40, by + 12), (41, by + 12)], "h")                    # navel
    # bloated body in a stretched purple #1 jersey
    ellipse(g, 40, by, 24, 18, "p")
    ellipse(g, 47, by + 5, 16, 11, "V")                             # shade (purple, not ink)
    ellipse(g, 31, by - 6, 9, 5, "X")                               # lit shoulder
    # shoulder pads under the jersey: a big dome on the left, the arm hides the right one
    ellipse(g, 24, by - 12, 10, 7, "p")
    ellipse(g, 22, by - 15, 6, 3, "X")                              # light on the pad
    rect(g, 15, by - 6, 30, by - 5, "V")                            # pad edge under the jersey
    put(g, [(15, by - 13), (15, by - 12), (16, by - 10), (16, by - 9)], "W")   # sleeve stripe
    rect(g, 17, by + 9, 63, by + 10, "X")                           # hem stripe
    rect(g, 37, by - 9, 43, by + 5, "W")                            # a big white #1
    rect(g, 34, by - 9, 37, by - 7, "W")
    rect(g, 34, by + 4, 46, by + 6, "W")
    put(g, [(28 + i * 3, by - 13 + (1 if i % 2 else 0)) for i in range(9)], "A")   # gold chain
    put(g, [(40, by - 9), (40, by - 8)], "U")                       # chain medallion
    # little left arm
    ellipse(g, 15, by - 2, 5, 9, "q")
    ellipse(g, 16, by + 1, 3, 5, "Q")
    # the monstrous throwing arm, posed
    arm = {"idle": ((67, by - 4), (68, by + 12), (70, by + 18)),
           "wind": ((64, by - 16), (64, 22), (65, 15)),
           "throw": ((62, by - 6), (54, by + 10), None),
           "audible": ((64, by - 16), (66, 22), (66, 15)),
           "slam": ((64, by - 18), (54, 18), (52, 12))}
    key = "idle" if rage and pose == "rage" else pose.replace("rage_", "")
    shoulder, hand, ball = arm.get(key, arm["idle"])
    ellipse(g, shoulder[0], shoulder[1], 11, 10, "q")
    mx, my = (shoulder[0] + hand[0]) / 2, (shoulder[1] + hand[1]) / 2
    ellipse(g, mx, my, 8, 10, "q")
    ellipse(g, hand[0], hand[1], 7, 6, "q")
    ellipse(g, mx + 3, my + 3, 4, 6, "Q")                           # arm shade
    put(g, [(mx - 3, my - 4), (mx - 2, my - 2), (mx - 3, my), (mx - 1, my + 2), (shoulder[0] - 4, shoulder[1] - 2),
            (shoulder[0] - 3, shoulder[1])], "i")                   # bulging veins
    if ball:
        ellipse(g, ball[0], ball[1], 7, 4.5, "F")                   # the ball
        ellipse(g, ball[0] - 1, ball[1] - 1, 5, 2.5, "E")
        rect(g, ball[0] - 3, ball[1], ball[0] + 3, ball[1], "W")
        put(g, [(ball[0] - 2, ball[1] - 1), (ball[0], ball[1] - 1), (ball[0] + 2, ball[1] - 1)], "W")
    if key == "throw":
        for i in range(4):                                          # whoosh lines
            put(g, [(46 - i * 4, by + 16 + i), (45 - i * 4, by + 16 + i)], "v")
    if key == "audible":
        ellipse(g, 12, 24, 4, 7, "q")                               # little arm up too
    # head sunk into the shoulders
    hy = 24 + bob + squash
    ellipse(g, 40, hy, 17, 15, "q")
    ellipse(g, 43, hy + 7, 13, 6, "Q")
    for sx in (-1, 1):                                              # giant black eyes
        ellipse(g, 40 + sx * 7, hy - 1, 4, 5, "e")
        put(g, [(40 + sx * 7 - 2, hy - 4)], "W")
        if rage:
            put(g, [(40 + sx * 7, hy)], "R")                        # red pinpricks
            put(g, [(40 + sx * 7, hy + 4 + k) for k in range(5)], "i")   # bleeding from the eyes
    ellipse(g, 40, hy + 9, 10, 4, "e")                              # manic grin
    for x in range(32, 49, 2):
        put(g, [(x, hy + 6), (x + 1, hy + 12)], "W")                # teeth
    put(g, [(36, hy + 13), (36, hy + 14), (35, hy + 15)], "i")      # drool
    # cracked gold helmet, facemask hanging off one side
    for y in range(hy - 16, hy - 4):
        for x in range(21, 60):
            if ((x - 40) / 18.5) ** 2 + ((y - (hy - 5)) / 12) ** 2 <= 1:
                g[y][x] = "A"
    ellipse(g, 46, hy - 9, 10, 5, "a")
    ellipse(g, 33, hy - 12, 6, 2.5, "U")
    rect(g, 22, hy - 5, 58, hy - 5, "a")                            # rim
    put(g, [(43, hy - 16), (44, hy - 15), (43, hy - 14), (45, hy - 13), (44, hy - 12)], "h")   # crack
    put(g, [(22, hy - 3), (22, hy + 1), (23, hy + 5), (24, hy + 9), (25, hy + 12)], "G")      # dangling bar
    put(g, [(23, hy - 3), (23, hy + 1), (24, hy + 5), (25, hy + 9), (26, hy + 12)], "m")
    if rage:                                                        # the helmet split open
        for y in range(hy - 17, hy - 9):
            for x in range(36, 46):
                if ((x - 41) / 5) ** 2 + ((y - (hy - 12)) / 4) ** 2 <= 1:
                    g[y][x] = "R"
        ellipse(g, 41, hy - 12, 2.5, 1.5, "i")
        put(g, [(38, hy - 10), (44, hy - 9), (47, hy - 8)], "i")
    return rows_of(outline(g))


# --- The Mascot (boss, 64x64): a giant mascot costume, the gaper inside staring out of its mouth ---
def mascot_boss(pose, frame=0):
    g = blank(64)
    bob = frame % 2
    squash = {"land": 6, "jump": -6}.get(pose, 0)
    lift = 8 if pose == "jump" else 0
    by = 40 + bob + squash - lift
    # big orange feet
    if pose != "jump":
        ellipse(g, 22, 58, 7, 3.5, "O")
        ellipse(g, 42, 58, 7, 3.5, "O")
        ellipse(g, 20, 57, 4, 1.5, "P")
    # furry, mangy body
    ellipse(g, 32, by + 4, 21, 15, "Y")
    ellipse(g, 36, by + 9, 16, 9, "y")                                    # shade (no ink)
    for x, y in ((14, by), (49, by + 2), (18, by + 12), (46, by + 13), (30, by + 17)):
        put(g, [(x, y), (x + 1, y + 1)], "y")                                # fur tufts
    ellipse(g, 32, by + 7, 9, 6, "W")                                     # belly patch with a number
    put(g, [(31, by + 4), (32, by + 4), (32, by + 5), (32, by + 6), (32, by + 7), (32, by + 8), (31, by + 9),
            (32, by + 9), (33, by + 9)], "B")
    # torn seam on the side: flesh and blood inside
    put(g, [(48, by - 2), (49, by - 1), (48, by), (49, by + 1), (48, by + 2)], "q")
    put(g, [(48, by + 3), (48, by + 4), (49, by + 5)], "i")
    # arms: pom-pom paws, or the t-shirt cannon raised
    if pose == "shoot":
        rect(g, 46, by - 16, 58, by - 11, "m")                            # cannon held high
        rect(g, 56, by - 18, 60, by - 9, "N")
        ellipse(g, 46, by - 8, 4, 4, "Y")
        put(g, [(62, by - 16), (63, by - 14), (62, by - 12)], "W")         # puff
    else:
        up = 10 if pose in ("jump", "land") else 0
        ellipse(g, 11, by + 2 - up, 5, 5, "Y")
        ellipse(g, 53, by + 2 - up, 5, 5, "Y")
    # the huge costume head
    hy = by - 20
    ellipse(g, 32, hy, 20, 16, "Y")
    ellipse(g, 36, hy + 6, 15, 8, "y")
    rect(g, 18, hy - 15, 46, hy - 13, "B")                                # team headband
    # googly eyes: one fine, one hanging off by a thread
    ellipse(g, 24, hy - 5, 5.5, 6, "W")
    put(g, [(25, hy - 3), (26, hy - 3), (25, hy - 2)], "e")
    ellipse(g, 43, hy + 3 + bob, 4.5, 4.5, "W")                           # dangling
    put(g, [(44, hy + 4 + bob), (43, hy + 5 + bob)], "e")
    put(g, [(41, hy - 5), (42, hy - 3), (42, hy - 1)], "k")               # the thread
    ellipse(g, 40, hy - 6, 3, 3, "D")                                     # the empty socket
    # the costume's mouth gapes open: the gaper inside stares out
    ellipse(g, 32, hy + 6, 9, 6, "D")
    ellipse(g, 32, hy + 7, 6.5, 4.5, "q")
    ellipse(g, 29.5, hy + 6, 1.6, 2, "e")
    ellipse(g, 34.5, hy + 6, 1.6, 2, "e")
    put(g, [(29, hy + 5), (34, hy + 5)], "W")
    ellipse(g, 32, hy + 9.5, 1.4, 1, "e")
    put(g, [(30, hy + 8), (30, hy + 9)], "i")
    rect(g, 26, hy + 1, 38, hy + 1, "O")                                  # the beak, split open
    rect(g, 27, hy + 12, 37, hy + 12, "O")
    if pose == "hurt":
        for x, y in ((10, hy - 10), (54, hy - 6), (8, by + 6), (56, by + 10)):
            put(g, [(x, y), (x + 1, y), (x, y + 1)], "Y")                   # fur flying off
    return rows_of(outline(g))


# --- The Linebacker (boss, 64x64) -----------------------------------------------
def linebacker(pose, frame=0):
    """Rival-team linebacker: silver helmet, black #99 jersey, huge pads."""
    g = blank(64)
    bob = frame % 2
    crouch = {"windup": 5, "charge": 4, "land": 7, "jump": -4}.get(pose, 0)
    lean = 7 if pose == "charge" else 0
    top = 14 + crouch + bob
    cx = 31 + lean

    # legs (black pants, cleats) - walking alternates the stride
    stride = (1 if frame % 2 else -1) * 3 if pose == "walk" else 0
    leg_top = 40 + max(crouch, 0) // 2 + bob
    rect(g, 22, leg_top, 29 + stride, 55, "k")
    rect(g, 34 - stride, leg_top, 41, 55, "k")
    rect(g, 20, 55, 29 + stride, 58, "n")
    rect(g, 34 - stride, 55, 43, 58, "n")
    rect(g, 22, 47 + bob, 29 + stride, 47 + bob, "W")          # pants stripe

    # torso: black jersey with white trim and number 99
    rect(g, cx - 13, top + 12, cx + 13, 41 + max(crouch, 0) // 2 + bob, "k")
    rect(g, cx - 13, top + 26, cx + 13, top + 26, "W")
    for nx in (cx - 7, cx + 1):                                # "99"
        rect(g, nx, top + 16, nx + 5, top + 23, "W")
        rect(g, nx + 2, top + 18, nx + 3, top + 19, "k")
        rect(g, nx, top + 21, nx + 3, top + 23, "k")
    # shoulder pads under the jersey, white sleeve stripes
    ellipse(g, cx - 13, top + 13, 7, 5, "k")
    ellipse(g, cx + 13, top + 13, 7, 5, "k")
    rect(g, cx - 19, top + 15, cx - 8, top + 15, "W")
    rect(g, cx + 8, top + 15, cx + 19, top + 15, "W")

    # arms
    if pose == "throw":
        reach = (-12, -4, 10)[frame % 3]
        rect(g, cx + 14, top + 6 + max(reach, -6), cx + 17, top + 22, "s")
        if frame % 3 != 2:
            ellipse(g, cx + 16 + reach // 2, top + 4 + reach // 2, 4, 2.5, "F")   # football in hand
    elif pose == "charge":
        rect(g, cx + 10, top + 18, cx + 20, top + 22, "s")      # forearm out front
    else:
        rect(g, cx - 19, top + 16, cx - 16, top + 30, "s")
        rect(g, cx + 16, top + 16, cx + 19, top + 30, "s")

    # helmet: silver shell, black stripe, black cage
    hx, hy = cx + (4 if pose == "charge" else 0), top + 2
    ellipse(g, hx, hy, 12, 11, "G")
    ellipse(g, hx - 4, hy - 4, 3, 2, "W")
    rect(g, hx - 1, hy - 11, hx + 1, hy - 1, "k")
    rect(g, hx - 7, hy + 1, hx + 7, hy + 9, "s")               # face
    rect(g, hx - 4, hy + 3, hx - 3, hy + 4, "e")
    rect(g, hx + 3, hy + 3, hx + 4, hy + 4, "e")
    if pose in ("windup", "charge"):
        put(g, [(hx - 5, hy + 2), (hx - 4, hy + 2), (hx + 4, hy + 2), (hx + 5, hy + 2)], "e")  # angry brows
    for by in (hy + 6, hy + 9):
        rect(g, hx - 8, by, hx + 8, by, "n")
    for bx in (hx - 3, hx + 3):
        rect(g, bx, hy + 6, bx, hy + 10, "n")

    if pose == "stunned":                                     # birdies
        for i, (sx, sy) in enumerate(((hx - 10, hy - 14), (hx, hy - 17), (hx + 10, hy - 14))):
            if (i + frame) % 2 == 0:
                put(g, [(sx, sy), (sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], "U")
    return rows_of(outline(g))


ENTITIES = {
    "monsters/gridiron_mascot": dict(
        frames=[mascot(i) for i in range(4)],
        anims={"Walk": ([0, 1], 8, True), "Shoot": ([2, 3, 3], 6, False)},
    ),
    "monsters/gridiron_referee": dict(
        frames=[referee(i) for i in range(4)],
        anims={"Walk": ([0, 1], 8, True), "Throw": ([2, 3, 3], 6, False)},
    ),
    "monsters/gridiron_lineman": dict(
        frames=[lineman(i) for i in range(5)],
        kit=kit("red", "white", "silver"),
        kits={"_captain": kit("red", "white", "silver", captain=True),
              **{f"_team_{c}": kit(c, "navy" if c == "white" else "white", "silver") for c in TEAM_COLORS},
              **{f"_team_{c}_captain": kit(c, "navy" if c == "white" else "white", "silver", captain=True)
                 for c in TEAM_COLORS}},
        anims={"Walk": ([0, 1], 8, True), "Dig": ([2], 1, True), "Charge": ([3, 4], 3, True)},
    ),
    "monsters/gridiron_blitzer": dict(
        frames=[blitzer(i) for i in range(3)],
        kit=kit("red", "white"), kits={"_captain": kit("red", "white", captain=True)},
        anims={"Fly": ([0, 1], 2, True), "Dive": ([2], 1, True)},
        pivot=(16, 24),
    ),
    "monsters/gridiron_punter": dict(
        frames=[punter(i) for i in range(4)],
        kit=kit("white", "navy"), kits={"_captain": kit("white", "navy", captain=True)},
        anims={"Idle": ([0, 1], 12, True), "Kick": ([2, 3, 3], 6, False)},
    ),
    "monsters/gridiron_huddle": dict(
        frames=[huddle(i) for i in range(4)],
        kit=kit("navy", "orange", "orange"), kits={"_captain": kit("navy", "orange", "orange", captain=True)},
        anims={"Walk": ([0, 1], 8, True), "Run": ([2, 3], 4, True)},
    ),
    "monsters/gridiron_cooler": dict(
        frames=[cooler(i) for i in range(2)],
        anims={"Walk": ([0, 1], 9, True)},
    ),
    "monsters/gridiron_chain_gang": dict(
        frames=[chain_ref(i) for i in range(2)],
        anims={"Walk": ([0, 1], 8, True)},
    ),
    "monsters/gridiron_chain": dict(
        size=8, pivot=(4, 4),
        frames=[chain_link(0)],
        anims={"Idle": ([0], 1, True)},
    ),
    "monsters/gridiron_sacker": dict(
        frames=[sacker(i) for i in range(6)],
        kit=kit("green", "gold"), kits={"_captain": kit("green", "gold", captain=True)},
        anims={"Mound": ([0, 1], 6, True), "Rise": ([2, 3], 3, True), "Up": ([4, 5], 8, True),
               "Dig": ([3, 2], 5, False)},
    ),
    "monsters/gridiron_coach": dict(
        size=48, pivot=(24, 44),
        frames=[coach(i) for i in range(4)],
        anims={"Idle": ([0, 1], 12, True), "Yell": ([2, 3], 5, True)},
    ),
    "bosses/gridiron_franchise": dict(
        size=80, pivot=(40, 77),
        frames=[franchise("idle", 0), franchise("idle", 1), franchise("wind"), franchise("throw"),
                franchise("audible"), franchise("slam"), franchise("rage", 0), franchise("rage", 1),
                franchise("rage_wind"), franchise("rage_throw")],
        anims={"Idle": ([0, 1], 10, True), "Wind": ([2], 1, True), "Throw": ([3], 1, True),
               "Audible": ([4], 1, True), "Slam": ([5], 1, True), "Rage": ([6, 7], 6, True),
               "RageWind": ([8], 1, True), "RageThrow": ([9], 1, True)},
    ),
    "bosses/gridiron_mascot_boss": dict(
        size=64, pivot=(32, 60),
        frames=[mascot_boss("idle", 0), mascot_boss("idle", 1), mascot_boss("shoot", 0), mascot_boss("shoot", 1),
                mascot_boss("jump", 0), mascot_boss("land", 0), mascot_boss("hurt", 0)],
        anims={"Idle": ([0, 1], 10, True), "Shoot": ([2, 3], 6, True), "Jump": ([4], 1, True),
               "Land": ([5], 1, True), "Hurt": ([6, 0], 4, False)},
    ),
    "bosses/gridiron_linebacker": dict(
        size=64,
        pivot=(32, 58),
        frames=[linebacker("idle", 0), linebacker("idle", 1),
                linebacker("walk", 0), linebacker("walk", 1),
                linebacker("windup", 0), linebacker("charge", 0), linebacker("charge", 1),
                linebacker("stunned", 0), linebacker("stunned", 1),
                linebacker("throw", 0), linebacker("throw", 1), linebacker("throw", 2),
                linebacker("jump", 0), linebacker("land", 0)],
        anims={
            "Idle": ([0, 1], 10, True),
            "Walk": ([2, 3], 7, True),
            "Windup": ([4], 25, False),
            "Charge": ([5, 6], 3, True),
            "Stunned": ([7, 8], 8, True),
            "Throw": ([9, 10, 11], 7, False),
            "Jump": ([12], 20, False),
            "Land": ([13], 12, False),
        },
    ),
    "familiars/gridiron_cheerleader": dict(
        icon="items/collectibles/cheerleader.png",
        frames=[cheerleader(i) for i in range(4)],
        anims={"Idle": ([0, 1], 8, True), "Cheer": ([2, 3, 2, 3, 2, 3], 4, False)},
    ),
    "familiars/gridiron_waterboy": dict(
        icon="items/collectibles/water_boy.png",
        frames=[water_boy(i) for i in range(4)],
        anims={"Idle": ([0, 1], 10, True), "Drop": ([2, 3, 2], 6, False)},
    ),
    "familiars/gridiron_tackling_dummy": dict(
        icon="items/collectibles/tackling_dummy.png",
        frames=[tackling_dummy(i) for i in range(2)],
        anims={"Idle": ([0], 1, True), "Hit": ([1, 0], 4, False)},
    ),
}


# --- anm2 ---------------------------------------------------------------------------
FRAME = ('<Frame XPosition="0" YPosition="0" XPivot="{px}" YPivot="{py}" XCrop="{x}" YCrop="0" '
         'Width="{s}" Height="{s}" XScale="100" YScale="100" Delay="{d}" Visible="true" RedTint="255" '
         'GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" BlueOffset="0" '
         'Rotation="0" Interpolated="false"/>')
ROOT_FRAME = ('<Frame XPosition="0" YPosition="0" XScale="100" YScale="100" Delay="{d}" Visible="true" '
              'RedTint="255" GreenTint="255" BlueTint="255" AlphaTint="255" RedOffset="0" GreenOffset="0" '
              'BlueOffset="0" Rotation="0" Interpolated="false"/>')


def anm2(sheet_name, size, anims, pivot):
    px, py = pivot
    out = ['<AnimatedActor>',
           '\t<Info CreatedBy="Gridiron tools/make_entities.py" CreatedOn="10/27/2026 12:00:00 PM" Version="1" Fps="30"/>',
           '\t<Content>',
           '\t\t<Spritesheets>',
           f'\t\t\t<Spritesheet Path="{sheet_name}" Id="0"/>',
           '\t\t</Spritesheets>',
           '\t\t<Layers>',
           '\t\t\t<Layer Name="body" Id="0" SpritesheetId="0"/>',
           '\t\t</Layers>',
           '\t\t<Nulls/>',
           '\t\t<Events/>',
           '\t</Content>',
           f'\t<Animations DefaultAnimation="{next(iter(anims))}">']
    for name, (frames, delay, loop) in anims.items():
        total = delay * len(frames)
        out.append(f'\t\t<Animation Name="{name}" FrameNum="{total}" Loop="{str(loop).lower()}">')
        out.append('\t\t\t<RootAnimation>')
        out.append('\t\t\t\t' + ROOT_FRAME.format(d=total))
        out.append('\t\t\t</RootAnimation>')
        out.append('\t\t\t<LayerAnimations>')
        out.append('\t\t\t\t<LayerAnimation LayerId="0" Visible="true">')
        for f in frames:
            out.append('\t\t\t\t\t' + FRAME.format(px=px, py=py, x=f * size, s=size, d=delay))
        out.append('\t\t\t\t</LayerAnimation>')
        out.append('\t\t\t</LayerAnimations>')
        out.append('\t\t\t<NullAnimations/>')
        out.append('\t\t\t<Triggers/>')
        out.append('\t\t</Animation>')
    out.append('\t</Animations>')
    out.append('</AnimatedActor>')
    return "\n".join(out) + "\n"


# --- Field decor (scripts/decor.lua): grungy props that never block anything ------------------
def grid(w, h):
    return [["."] * w for _ in range(h)]


def rect_rows(g):
    return ["".join(r) for r in g]


DECOR_FADE = {"y": (238, 238, 228, 110), "Y_": (238, 238, 228, 70)}


def decor_props():
    """name -> (rows, floor?, pivot) for every prop. Floor props lie flat (rendered under
    everything); upright ones stand on their pivot."""
    import random
    rnd = random.Random(31)
    props = {}

    # painted field: faded, scuffed white paint (the translucent keys are added below)
    g = grid(3, 150)
    for y in range(150):
        if rnd.random() > 0.12:                           # scuffed gaps
            for x in range(3):
                g[y][x] = "1" if rnd.random() > 0.25 else "2"
    props["Yardline"] = (rect_rows(g), True, (1, 75))
    g = grid(10, 3)
    for x in (0, 1, 8, 9):
        for y in range(3):
            g[y][x] = "1"
    props["Hash"] = (rect_rows(g), True, (5, 1))
    g = grid(150, 3)                                       # a sideline, along a wall
    for x in range(150):
        if rnd.random() > 0.12:
            for y in range(3):
                g[y][x] = "1" if rnd.random() > 0.25 else "2"
    props["Sideline"] = (rect_rows(g), True, (75, 1))
    digits = {"1": ["01", "11", "01", "01", "01"], "2": ["11", "01", "11", "10", "11"],
              "3": ["11", "01", "11", "01", "11"], "4": ["101", "101", "111", "001", "001"],
              "5": ["11", "10", "11", "01", "11"], "0": ["111", "101", "101", "101", "111"]}
    for num in ("10", "20", "30", "40", "50"):            # painted yard numbers, 3x scale
        cols = sum(len(digits[c][0]) for c in num) + 1
        g = grid(cols * 3 + 2, 17)
        x0 = 1
        for c in num:
            for yy, row in enumerate(digits[c]):
                for xx, bit in enumerate(row):
                    if bit == "1":
                        for dy in range(3):
                            for dx in range(3):
                                if rnd.random() > 0.15:
                                    g[1 + yy * 3 + dy][x0 + xx * 3 + dx] = "1"
            x0 += len(digits[c][0]) * 3 + 3
        props["Num" + num] = (rect_rows(g), True, (len(g[0]) // 2, 8))
    g = grid(64, 44)                                       # end zone corner stripes
    for k in range(-44, 64, 10):
        for y in range(44):
            for w in range(4):
                x = k + y + w
                if 0 <= x < 64 and rnd.random() > 0.2:
                    g[y][x] = "3"
    props["EndStripes"] = (rect_rows(g), True, (32, 22))
    g = grid(56, 36)
    ellipse(g, 27.5, 17.5, 27, 17, "3")                    # scrubbed team logo
    ellipse(g, 27.5, 17.5, 22, 13, ".")
    ellipse(g, 27.5, 17.5, 14, 8, "3")                     # a football in the middle
    rect(g, 18, 17, 37, 17, "1")
    for x in range(20, 37, 3):
        g[16][x] = "1"
        g[18][x] = "1"
    for y in range(36):
        for x in range(56):
            if g[y][x] != "." and rnd.random() < 0.3:
                g[y][x] = "."                              # half scrubbed away
    props["Logo"] = (rect_rows(g), True, (28, 18))

    # sideline junk
    g = grid(18, 10)
    ellipse(g, 9, 6, 8, 3.5, "4")                          # gatorade stain under the cups
    rect(g, 2, 3, 5, 6, "W")                               # crushed cups
    rect(g, 2, 3, 5, 3, "w")
    rect(g, 10, 5, 15, 7, "W")
    rect(g, 10, 5, 10, 7, "O")
    put(g, [(7, 4), (8, 5)], "O")
    props["Cups"] = (rect_rows(outline_soft(g)), True, (9, 5))
    g = grid(26, 12)
    ellipse(g, 13, 6, 12, 5, "4")
    ellipse(g, 9, 5, 5, 2, "5")
    props["Stain"] = (rect_rows(g), True, (13, 6))
    g = grid(30, 20)
    ellipse(g, 20, 15, 10, 4, "4")                         # what spilled out
    rect(g, 3, 6, 18, 16, "O")                             # cooler on its side
    rect(g, 3, 6, 18, 7, "P")
    rect(g, 3, 15, 18, 16, "o")
    ellipse(g, 19, 11, 2, 5, "W")                          # open end, lid gone
    ellipse(g, 19, 11, 1, 3.5, "o")
    rect(g, 6, 9, 14, 11, "W")                             # label
    put(g, [(8, 10), (10, 10), (12, 10)], "O")
    rect(g, 7, 4, 8, 5, "v")                               # handle
    props["Cooler"] = (rect_rows(outline(g)), False, (12, 17))
    g = grid(26, 18)
    ellipse(g, 9, 11, 8, 6, "v")                           # mesh ball bag
    for x in range(2, 17, 2):
        for y in range(6, 17):
            if g[y][x] == "v":
                g[y][x] = "N"
    for cx, cy in ((19, 13), (22, 9), (14, 15)):           # balls spilling out
        ellipse(g, cx, cy, 3.5, 2.2, "F")
        put(g, [(cx, cy - 1)], "W")
    props["BallBag"] = (rect_rows(outline(g)), False, (12, 15))
    g = grid(12, 16)
    for y in range(3, 14):                                 # a pylon, kicked over and bent
        x0 = 2 + (y - 3) // 3
        for x in range(x0, x0 + 4):
            g[y][x] = "O"
    put(g, [(4, 7), (5, 7), (6, 8), (7, 8)], "W")
    rect(g, 3, 13, 9, 14, "o")
    props["Pylon"] = (rect_rows(outline(g)), False, (6, 13))
    g = grid(20, 14)
    ellipse(g, 9, 7, 8, 6, "m")                            # a dented rival helmet, face down
    ellipse(g, 7, 5, 4, 2, "W")
    put(g, [(10, 3), (11, 4), (10, 5), (12, 6)], "n")      # dent and crack
    rect(g, 15, 6, 18, 10, "G")                            # facemask poking out
    put(g, [(16, 8), (17, 8)], "n")
    props["Helmet"] = (rect_rows(outline(g)), False, (10, 11))
    g = grid(12, 7)
    ellipse(g, 3, 3, 2.5, 2, "W")
    ellipse(g, 8, 4, 2, 1.6, "w")
    props["Tape"] = (rect_rows(outline_soft(g)), True, (6, 3))
    g = grid(14, 16)
    rect(g, 1, 1, 12, 14, "d")                             # muddy clipboard
    rect(g, 3, 3, 10, 13, "W")
    put(g, [(4, 5), (6, 7), (8, 9), (5, 11), (9, 5)], "R")
    put(g, [(7, 5), (4, 9)], "B")
    put(g, [(9, 12), (10, 11)], "d")
    props["Clipboard"] = (rect_rows(outline(g)), True, (7, 8))
    g = grid(12, 7)
    ellipse(g, 5.5, 3, 5, 2.4, "W")                        # chewed, bloody mouthguard
    ellipse(g, 5.5, 3.5, 3, 1.2, ".")
    put(g, [(2, 2), (8, 4)], "i")
    props["Mouthguard"] = (rect_rows(outline(g)), True, (6, 3))
    g = grid(20, 12)
    ellipse(g, 10, 6, 9, 4, "i")                           # someone got tackled here
    ellipse(g, 8, 5, 4, 2, "R")
    put(g, [(18, 3), (2, 9), (17, 10)], "i")
    props["Blood"] = (rect_rows(g), True, (10, 6))

    # set pieces
    g = grid(30, 66)
    rect(g, 13, 26, 16, 64, "Y")                           # goalpost upright with padding
    rect(g, 13, 26, 13, 64, "U")
    rect(g, 16, 26, 16, 64, "y")
    rect(g, 2, 24, 27, 27, "Y")                            # crossbar stub
    rect(g, 2, 24, 27, 24, "U")
    rect(g, 3, 0, 5, 24, "Y")                              # uprights
    rect(g, 24, 0, 26, 24, "Y")
    rect(g, 3, 0, 3, 24, "U")
    rect(g, 24, 0, 24, 24, "U")
    rect(g, 11, 50, 18, 64, "B")                           # base pad
    rect(g, 11, 50, 12, 64, "L")
    put(g, [(14, 55), (15, 58), (16, 61)], "b")
    rect(g, 3, 6, 5, 7, "R")                               # a torn flag
    props["Goalpost"] = (rect_rows(outline(g)), False, (14, 64))
    g = grid(50, 18)
    rect(g, 1, 4, 48, 8, "f")                              # bench
    rect(g, 1, 4, 48, 4, "E")
    rect(g, 3, 9, 5, 16, "n")
    rect(g, 44, 9, 46, 16, "n")
    rect(g, 18, 1, 27, 8, "W")                             # towel draped over it
    rect(g, 18, 8, 22, 12, "W")
    put(g, [(19, 2), (23, 3), (21, 10)], "w")
    ellipse(g, 36, 3, 4, 2, "O")                           # a lone cup
    props["Bench"] = (rect_rows(outline(g)), False, (25, 16))
    g = grid(40, 26)
    rect(g, 2, 20, 37, 23, "m")                            # sled runners
    rect(g, 4, 18, 35, 19, "n")
    rect(g, 6, 4, 15, 18, "R")                             # two pads
    rect(g, 24, 4, 33, 18, "R")
    rect(g, 6, 4, 7, 18, "H")
    rect(g, 24, 4, 25, 18, "H")
    rect(g, 6, 10, 15, 11, "W")
    rect(g, 24, 10, 33, 11, "W")
    put(g, [(12, 6), (13, 7), (30, 14), (31, 15)], "r")    # worn spots
    props["Sled"] = (rect_rows(outline(g)), False, (20, 23))
    g = grid(50, 18)
    rect(g, 0, 2, 49, 15, "B")                             # stadium banner, torn at a corner
    rect(g, 0, 2, 49, 3, "Y")
    rect(g, 0, 14, 49, 15, "Y")
    for i, x in enumerate(range(8, 42, 9)):                # "GO!" blocks
        rect(g, x, 6, x + 5, 11, "W")
    put(g, [(49, 15), (48, 15), (49, 14)], ".")
    rect(g, 2, 0, 3, 2, "n")
    rect(g, 46, 0, 47, 2, "n")
    props["Banner"] = (rect_rows(outline(g)), False, (25, 17))

    # locker room
    for name, open_door in (("Locker", False), ("LockerOpen", True)):
        g = grid(20, 42)
        rect(g, 1, 1, 18, 40, "N")                         # dented steel locker
        rect(g, 1, 1, 3, 40, "G")
        rect(g, 16, 1, 18, 40, "n")
        for y in (5, 7, 9):                                # vents
            rect(g, 6, y, 13, y, "n")
        rect(g, 14, 18, 15, 22, "v")                       # handle
        put(g, [(9, 26), (10, 27), (8, 28), (11, 30)], "v")  # dents
        put(g, [(5, 33), (6, 34), (12, 36)], "d")          # rust
        rect(g, 1, 40, 18, 41, "n")
        if open_door:
            rect(g, 3, 3, 15, 38, "D")                     # dark inside
            rect(g, 5, 8, 13, 20, "B")                     # a jersey hanging
            rect(g, 5, 8, 6, 20, "L")
            rect(g, 8, 11, 10, 15, "W")
            ellipse(g, 9, 30, 4, 3, "R")                   # a helmet on the shelf
            put(g, [(12, 34), (12, 35), (11, 36)], "i")    # something dripping
        props[name] = (rect_rows(outline(g)), False, (10, 41))
    g = grid(46, 32)
    rect(g, 1, 1, 44, 26, "W")                             # whiteboard of plays
    rect(g, 1, 1, 44, 1, "v")
    rect(g, 1, 26, 44, 26, "v")
    for x, y in ((8, 8), (16, 6), (24, 9), (32, 7)):
        put(g, [(x, y), (x + 1, y + 1), (x + 1, y), (x, y + 1)], "R")   # X's
    for x, y in ((10, 18), (20, 20), (30, 18), (38, 19)):
        ellipse(g, x, y, 2, 2, "B")                        # O's
        ellipse(g, x, y, 1, 1, "W")
    for i in range(10):
        put(g, [(12 + i * 2, 16 - i // 2)], "k")           # route arrows
    put(g, [(33, 9), (34, 10), (35, 11), (36, 12), (37, 13)], "k")
    put(g, [(40, 4), (41, 5), (39, 22), (6, 22)], "i")     # someone wrote in blood
    rect(g, 6, 27, 7, 31, "n")
    rect(g, 38, 27, 39, 31, "n")
    props["Whiteboard"] = (rect_rows(outline(g)), False, (23, 31))
    g = grid(16, 12)
    ellipse(g, 7.5, 6, 7, 5, "n")                          # floor drain
    for x in range(3, 13, 2):
        rect(g, x, 3, x, 9, "D")
    props["Drain"] = (rect_rows(outline(g)), True, (8, 6))
    g = grid(30, 14)
    ellipse(g, 15, 7, 14, 6, "6")                          # shower puddle
    ellipse(g, 11, 6, 6, 2, "7")
    props["Puddle"] = (rect_rows(g), True, (15, 7))
    g = grid(22, 14)
    ellipse(g, 11, 7, 10, 5, "W")                          # a crumpled, bloody towel
    put(g, [(5, 6), (8, 9), (14, 4), (17, 8)], "w")
    ellipse(g, 14, 8, 3, 2, "i")
    props["Towel"] = (rect_rows(outline(g)), True, (11, 7))
    g = grid(24, 16)
    rect(g, 3, 4, 20, 13, "B")                             # a jersey on the floor
    rect(g, 0, 4, 3, 8, "B")
    rect(g, 20, 4, 23, 8, "B")
    rect(g, 8, 2, 15, 4, "L")
    rect(g, 9, 6, 13, 11, "W")
    put(g, [(4, 12), (19, 11), (17, 5)], "b")
    props["JerseyFloor"] = (rect_rows(outline(g)), True, (12, 8))
    g = grid(18, 24)
    rect(g, 2, 6, 15, 22, "n")                             # trash can of cups
    rect(g, 2, 6, 4, 22, "N")
    rect(g, 1, 4, 16, 6, "N")
    for x, y in ((4, 2), (8, 1), (12, 3), (6, 4)):
        rect(g, x, y, x + 2, y + 2, "W")
    put(g, [(13, 1), (14, 2)], "O")
    props["Trash"] = (rect_rows(outline(g)), False, (9, 23))

    # practice field
    g = grid(10, 10)
    for y in range(2, 9):                                  # a training cone
        half = (y - 1) // 2
        rect(g, 4 - half, y, 5 + half, y, "O")
    rect(g, 4, 2, 5, 3, "P")
    rect(g, 0, 8, 9, 9, "o")
    props["Cone"] = (rect_rows(outline(g)), False, (5, 9))
    g = grid(26, 96)
    for x in (2, 23):                                      # agility ladder, taped on the floor
        rect(g, x, 1, x + 1, 94, "Y")
    for y in range(4, 94, 12):
        rect(g, 2, y, 24, y + 1, "Y")
    for y in range(96):
        for x in range(26):
            if g[y][x] == "Y" and (x * 7 + y * 3) % 11 == 0:
                g[y][x] = "."                              # scuffed
    props["Ladder"] = (rect_rows(g), True, (13, 48))
    g = grid(22, 14)
    ellipse(g, 11, 7, 10, 6, "k")                          # a drill tire
    ellipse(g, 11, 7, 10, 6, "n")
    ellipse(g, 11, 7, 5, 2.5, ".")
    put(g, [(4, 4), (16, 3), (19, 9)], "N")
    props["Tire"] = (rect_rows(outline(g)), False, (11, 10))

    # turf: torn patches of filthy old artificial turf laid over the floor
    for name, (w, h) in (("Turf", (80, 56)), ("TurfSmall", (44, 30))):
        g = grid(w, h)
        for y in range(h):
            for x in range(w):
                d = ((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2
                if d < 0.85 + 0.25 * rnd.random():           # ragged torn edge
                    g[y][x] = "8" if rnd.random() > 0.3 else "9"
        for _ in range(w * h // 60):                       # grime, dirt and a stain or two
            x, y = rnd.randrange(w), rnd.randrange(h)
            if g[y][x] != ".":
                g[y][x] = "d" if rnd.random() < 0.7 else "i"
        props[name] = (rect_rows(g), True, (w // 2, h // 2))
    return props


def outline_soft(g):
    """Outline only the opaque (non-stain) parts, so puddles stay soft-edged."""
    h, w = len(g), len(g[0])
    soft = {"4", "5", "1", "2", "3"}
    edge = [(x, y) for y in range(h) for x in range(w) if g[y][x] == "."
            and any(0 <= x + dx < w and 0 <= y + dy < h and g[y + dy][x + dx] not in {".", "K"} | soft
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    put(g, edge, "K")
    return g


# Only floor paint for the football fields, plus the Pylon trinket's marker. The standing props
# (lockers, goalposts, benches, junk) are gone: they never fit Isaac's rooms.
DECOR_KEPT = ("Pylon", "Yardline", "EndStripes", "TurfSmall", "Num10", "Num20", "Num30", "Num40", "Num50")


def decor_sheet():
    """Pack every prop into one strip and write a matching anm2 (one animation per prop)."""
    from PIL import Image
    extra = {"1": (236, 236, 226, 115), "2": (236, 236, 226, 60), "3": (236, 236, 226, 70),
             "4": (238, 122, 32, 95), "5": (255, 176, 86, 70),
             "6": (120, 150, 170, 90), "7": (200, 225, 240, 80),          # shower water
             "8": (52, 92, 46, 170), "9": (40, 74, 38, 170)}               # filthy turf
    pal = dict(PALETTE, **extra)
    props = {name: v for name, v in decor_props().items() if name in DECOR_KEPT}
    widths = [len(rows[0]) for rows, _, _ in props.values()]
    height = max(len(rows) for rows, _, _ in props.values())
    sheet = Image.new("RGBA", (sum(widths) + 2 * len(widths), height), (0, 0, 0, 0))
    frames, x = [], 0
    for name, (rows, floor, pivot) in props.items():
        w, h = len(rows[0]), len(rows)
        for yy, row in enumerate(rows):
            for xx, ch in enumerate(row):
                sheet.putpixel((x + xx, yy), pal[ch])
        frames.append((name, x, w, h, pivot))
        x += w + 2
    anims = []
    for name, fx, w, h, (pxv, pyv) in frames:
        frame_xml = (FRAME.format(px=pxv, py=pyv, x=fx, s=w, d=1)
                     .replace(f'Height="{w}"', f'Height="{h}"', 1))
        anims.append(f'''\t\t<Animation Name="{name}" FrameNum="1" Loop="true">
\t\t\t<RootAnimation>{ROOT_FRAME.format(d=1)}</RootAnimation>
\t\t\t<LayerAnimations><LayerAnimation LayerId="0" Visible="true">{frame_xml}</LayerAnimation></LayerAnimations>
\t\t\t<NullAnimations/><Triggers/>
\t\t</Animation>''')
    anm2 = ('''<AnimatedActor>
\t<Info CreatedBy="Gridiron tools/make_entities.py" CreatedOn="11/08/2026 12:00:00 PM" Version="1" Fps="30"/>
\t<Content>
\t\t<Spritesheets><Spritesheet Path="gridiron_decor.png" Id="0"/></Spritesheets>
\t\t<Layers><Layer Name="prop" Id="0" SpritesheetId="0"/></Layers>
\t\t<Nulls/><Events/>
\t</Content>
\t<Animations DefaultAnimation="Pylon">
''' + "\n".join(anims) + '''
\t</Animations>
</AnimatedActor>
''')
    return sheet, anm2


END_ZONE_W, END_ZONE_H = 80, 40


def end_zone_paint():
    """The End Zone floor marking: translucent blue/green diagonal stripes in a white border.
    Translucent so the room's own floor shows through the paint."""
    from PIL import Image
    img = Image.new("RGBA", (END_ZONE_W, END_ZONE_H), (0, 0, 0, 0))
    px = img.load()
    for y in range(END_ZONE_H):
        for x in range(END_ZONE_W):
            border = x < 2 or y < 2 or x >= END_ZONE_W - 2 or y >= END_ZONE_H - 2
            if border:
                px[x, y] = (245, 245, 238, 220)
            elif ((x + y) // 6) % 2 == 0:
                px[x, y] = (40, 74, 170, 120)       # team blue stripe
            else:
                px[x, y] = (64, 140, 58, 70)        # turf green
    return img


def end_zone_anm2():
    return ('''<AnimatedActor>
\t<Info CreatedBy="Gridiron tools/make_entities.py" CreatedOn="11/07/2026 12:00:00 PM" Version="1" Fps="30"/>
\t<Content>
\t\t<Spritesheets><Spritesheet Path="gridiron_end_zone.png" Id="0"/></Spritesheets>
\t\t<Layers><Layer Name="paint" Id="0" SpritesheetId="0"/></Layers>
\t\t<Nulls/><Events/>
\t</Content>
\t<Animations DefaultAnimation="Idle">
\t\t<Animation Name="Idle" FrameNum="1" Loop="true">
\t\t\t<RootAnimation>''' + ROOT_FRAME.format(d=1) + '''</RootAnimation>
\t\t\t<LayerAnimations>
\t\t\t\t<LayerAnimation LayerId="0" Visible="true">''' +
            FRAME.format(px=END_ZONE_W // 2, py=END_ZONE_H // 2, x=0, s=END_ZONE_W, d=1)
            .replace(f'Height="{END_ZONE_W}"', f'Height="{END_ZONE_H}"') + '''</LayerAnimation>
\t\t\t</LayerAnimations>
\t\t\t<NullAnimations/><Triggers/>
\t\t</Animation>
\t</Animations>
</AnimatedActor>
''')


def main():
    from PIL import Image
    from iconstyle import finish
    effects = GFX / "effects"
    effects.mkdir(parents=True, exist_ok=True)
    end_zone_paint().save(effects / "gridiron_end_zone.png")
    decor, decor_anm2 = decor_sheet()
    decor.save(effects / "gridiron_decor.png")
    (effects / "gridiron_decor.anm2").write_text(decor_anm2)
    (effects / "gridiron_end_zone.anm2").write_text(end_zone_anm2())
    for rel, spec in ENTITIES.items():
        size = spec.get("size", 32)
        frames = spec["frames"]
        png = GFX / f"{rel}.png"
        png.parent.mkdir(parents=True, exist_ok=True)
        # Football players render once per kit: the base sheet, plus alternates (captains, the
        # Tainted Coach's squad in your colours) that scripts swap in with ReplaceSpritesheet.
        for suffix, colours in {"": spec.get("kit", {}), **spec.get("kits", {})}.items():
            PALETTE.update(colours)
            strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
            for i, rows in enumerate(frames):
                strip.paste(render_rows(rows, size), (i * size, 0))
            strip.save(png.with_name(png.stem + suffix + ".png"))
        PALETTE.update(kit("red"))
        if "icon" in spec:   # pedestal sprite = the first frame
            finish(render_rows(frames[0], size)).save(GFX / spec["icon"])
        pivot = spec.get("pivot", (size // 2, size - 4))
        (GFX / f"{rel}.anm2").write_text(anm2(png.name, size, spec["anims"], pivot))
    print(f"{len(ENTITIES)} entities written")


if __name__ == "__main__":
    main()
