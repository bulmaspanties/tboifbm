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
for key, col in {"j": (255, 255, 255, 200), "J": (214, 228, 242, 110),
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
def low_helmet(g, cx, cy, r, shell, shade, stripe="W", mask=True):
    """A helmet sitting low: only the giant eyes and a grimace show through the gap."""
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
    g = blank()
    pose = ["walk", "walk", "dig", "charge", "charge"][frame]
    step = frame % 2
    down = 2 if pose == "dig" else 0
    lean = 2 if pose == "charge" else 0
    # wide stance: legs splayed
    spread = 1 if step else 0
    put(g, [(9 - spread, 28), (10 - spread, 27), (10, 26), (11, 25)], "Q")
    put(g, [(22 + spread, 28), (21 + spread, 27), (21, 26), (20, 25)], "Q")
    rect(g, 7 - spread, 28, 10 - spread, 28, "h")
    rect(g, 21 + spread, 28, 24 + spread, 28, "h")
    # hunched torso, shoulders pushing straight out of the neck
    ellipse(g, 16 + lean, 21 + down, 10, 5.5, "N")
    ellipse(g, 16 + lean, 23 + down, 8, 3, "n")
    rect(g, 7 + lean, 20 + down, 25 + lean, 20 + down, "i")         # dark red stripe
    put(g, [(11 + lean, 23 + down), (19 + lean, 24 + down)], "q")    # torn jersey, flesh showing
    ellipse(g, 7 + lean, 15 + down, 5, 3.6, "W")                    # pads hunched up high
    ellipse(g, 25 + lean, 15 + down, 5, 3.6, "W")
    ellipse(g, 7 + lean, 16.5 + down, 4, 1.8, "w")
    ellipse(g, 25 + lean, 16.5 + down, 4, 1.8, "w")
    low_helmet(g, 16 + lean, 14 + down, 5.5, "R", "r")              # head sunk between the pads
    put(g, [(14 + lean, 8 + down), (13 + lean, 9 + down)], "r")      # crack in the shell
    if pose == "charge":
        put(g, [(16 + lean, 21 + down), (16 + lean, 22 + down)], "i")   # drool flying
    if pose == "dig":
        put(g, [(4, 28), (6, 29), (26, 29), (28, 28), (5, 26)], "d")    # dirt clods
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
    put(g, [(14, 21), (16, 22), (18, 21), (15, 23), (17, 23)], "h")              # belly bands
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
    g = blank()
    kick = frame - 1 if frame >= 2 else 0                           # 0 idle, 1 wind, 2 kick
    bob = frame % 2 if frame < 2 else 0
    ellipse(g, 15, 21 + bob, 6, 5, "W")                             # round torso, white kicker jersey
    ellipse(g, 16, 23 + bob, 4.5, 2.5, "w")
    put(g, [(15, 19 + bob), (16, 20 + bob), (16, 21 + bob), (16, 22 + bob)], "n")   # #1
    # thin floppy arms
    put(g, [(9, 20 + bob), (8, 21 + bob), (7, 23 + bob), (7, 24 + bob)], "Q")
    put(g, [(21, 20 + bob), (22, 22 + bob), (23, 23 + bob), (22, 25 + bob)], "Q")
    put(g, [(13, 26), (13, 27), (12, 28)], "Q")                     # planted leg
    rect(g, 10, 28, 13, 28, "h")
    if kick == 0:
        put(g, [(17, 26), (18, 27), (18, 28)], "Q")
        rect(g, 18, 28, 21, 28, "h")
    elif kick == 1:                                                 # leg flung back
        put(g, [(12, 25), (10, 25), (9, 24), (7, 23), (6, 22)], "Q")
        rect(g, 4, 21, 6, 22, "h")
    else:                                                           # leg whipped up, way too high
        put(g, [(18, 24), (20, 22), (21, 21), (22, 19), (23, 17), (24, 15), (19, 23)], "Q")
        rect(g, 24, 13, 27, 15, "h")
    gaper_face(g, 15, 11 + bob, 7.2, mouth="o")                     # bulbous gaper head, screaming
    return rows_of(outline(g))


# --- Huddle: little Chargers in orange helmets, hunched together ---------------------
def huddle(frame):
    g = blank()
    step = frame % 2
    running = frame >= 2
    ellipse(g, 16, 21, 6.5, 4, "W")                                 # hunched jersey
    rect(g, 10, 21, 22, 21, "o")
    ellipse(g, 11, 17.5, 3, 2.2, "W")                               # pads
    ellipse(g, 21, 17.5, 3, 2.2, "W")
    put(g, [(12, 25), (11, 26), (11 - step, 27)], "Q")
    put(g, [(20, 25), (21, 26), (21 + step, 27)], "Q")
    low_helmet(g, 16, 14, 4.6, "O", "o", mask=False)
    if running:
        put(g, [(16, 19), (16, 20)], "i")                           # drool
        put(g, [(6, 14), (5, 16), (26, 14), (27, 16)], "v")        # speed lines
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
        ellipse(g, 16 + shake, 19, 6, 5, "n")                       # mud-caked helmet breaking through
        put(g, [(14 + shake, 16), (18 + shake, 17), (16 + shake, 15)], "d")
        put(g, [(6, 20), (26, 20), (8 + shake, 15), (24 - shake, 14), (11, 12), (21, 12)], "d")   # dirt spray
        return rows_of(outline(g))
    lift = frame - 4
    dirt_hole(g, 16, 26, 10, 3.4, 0)
    ellipse(g, 16, 19 - lift, 7, 5.5, "Q")                         # body out of the hole
    put(g, [(6, 16 - lift), (7, 17 - lift), (8, 18 - lift), (9, 18 - lift)], "q")   # claw arms up
    put(g, [(26, 16 - lift), (25, 17 - lift), (24, 18 - lift), (23, 18 - lift)], "q")
    put(g, [(5, 15 - lift), (7, 15 - lift), (25, 15 - lift), (27, 15 - lift)], "W")   # claws
    low_helmet(g, 16, 12 - lift, 5.6, "n", "N", stripe="d", mask=False)
    put(g, [(13, 7 - lift), (18, 8 - lift), (20, 10 - lift), (12, 10 - lift), (15, 6 - lift)], "d")   # heavy with mud
    put(g, [(16, 18 - lift), (16, 19 - lift)], "i")
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
        anims={"Walk": ([0, 1], 8, True), "Dig": ([2], 1, True), "Charge": ([3, 4], 3, True)},
    ),
    "monsters/gridiron_blitzer": dict(
        frames=[blitzer(i) for i in range(3)],
        anims={"Fly": ([0, 1], 2, True), "Dive": ([2], 1, True)},
        pivot=(16, 24),
    ),
    "monsters/gridiron_punter": dict(
        frames=[punter(i) for i in range(4)],
        anims={"Idle": ([0, 1], 12, True), "Kick": ([2, 3, 3], 6, False)},
    ),
    "monsters/gridiron_huddle": dict(
        frames=[huddle(i) for i in range(4)],
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
        anims={"Mound": ([0, 1], 6, True), "Rise": ([2, 3], 3, True), "Up": ([4, 5], 8, True),
               "Dig": ([3, 2], 5, False)},
    ),
    "monsters/gridiron_coach": dict(
        size=48, pivot=(24, 44),
        frames=[coach(i) for i in range(4)],
        anims={"Idle": ([0, 1], 12, True), "Yell": ([2, 3], 5, True)},
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
    (effects / "gridiron_end_zone.anm2").write_text(end_zone_anm2())
    for rel, spec in ENTITIES.items():
        size = spec.get("size", 32)
        frames = spec["frames"]
        strip = Image.new("RGBA", (size * len(frames), size), (0, 0, 0, 0))
        for i, rows in enumerate(frames):
            strip.paste(render_rows(rows, size), (i * size, 0))
        png = GFX / f"{rel}.png"
        png.parent.mkdir(parents=True, exist_ok=True)
        strip.save(png)
        if "icon" in spec:   # pedestal sprite = the first frame
            finish(render_rows(frames[0], size)).save(GFX / spec["icon"])
        pivot = spec.get("pivot", (size // 2, size - 4))
        (GFX / f"{rel}.anm2").write_text(anm2(png.name, size, spec["anims"], pivot))
    print(f"{len(ENTITIES)} entities written")


if __name__ == "__main__":
    main()
