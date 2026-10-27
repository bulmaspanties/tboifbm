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
    g = blank()
    step = frame % 2
    shooting = frame >= 2
    cx = 12
    rect(g, cx - 5, 18, cx + 5, 25, "Y")                       # furry body
    rect(g, cx - 5, 24, cx + 5, 25, "y")
    rect(g, cx - 4, 26, cx - 2, 27 - step, "O")                # big orange feet
    rect(g, cx + 2, 26, cx + 4, 26 + step, "O")
    ellipse(g, cx, 11, 7.5, 7, "Y")                            # mascot head
    ellipse(g, cx - 3, 10, 2.2, 2.6, "W")                      # googly eyes
    ellipse(g, cx + 3, 10, 2.2, 2.6, "W")
    put(g, [(cx - 3, 11), (cx + 3, 10)], "e")
    rect(g, cx - 2, 14, cx + 2, 15, "O")                       # beak
    rect(g, cx - 1, 16, cx + 1, 16, "o")
    rect(g, cx - 6, 3, cx + 6, 4, "B")                         # team headband
    # t-shirt cannon
    kick = -1 if shooting and frame == 2 else 0
    rect(g, cx + 4 + kick, 18, cx + 13 + kick, 21, "m")
    rect(g, cx + 12 + kick, 17, cx + 14 + kick, 22, "g")
    if frame == 2:
        put(g, [(cx + 16, 18), (cx + 17, 20), (cx + 16, 22), (cx + 18, 19)], "W")   # muzzle puff
    return rows_of(outline(g))


# --- Referee: Walk and Throw (flag up) -------------------------------------------
def referee(frame):
    g = blank()
    step = frame % 2
    throwing = frame >= 2
    cx = 15
    rect(g, cx - 4, 18, cx + 4, 23, "W")                       # striped shirt
    for x in range(cx - 4, cx + 5, 2):
        rect(g, x, 18, x, 23, "k")
    rect(g, cx - 3, 24, cx - 1, 27 - step, "k")                # black pants
    rect(g, cx + 1, 24, cx + 3, 26 + step, "k")
    head(g, cx, 12)
    rect(g, cx - 6, 5, cx + 6, 7, "k")                         # black cap
    rect(g, cx - 7, 7, cx + 3, 7, "n")
    put(g, [(cx + 1, 16), (cx + 2, 16)], "m")                  # whistle
    if throwing:
        rect(g, cx + 5, 6 if frame == 3 else 9, cx + 6, 17, "s")   # arm up
        rect(g, cx + 7, 3 if frame == 3 else 6, cx + 11, 7 if frame == 3 else 10, "Y")  # flag
    else:
        rect(g, cx + 5, 19, cx + 6, 22, "s")
        rect(g, cx + 6, 21, cx + 8, 23, "Y")                   # flag tucked in the belt
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


def main():
    from PIL import Image
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
            render_rows(frames[0], size).save(GFX / spec["icon"])
        pivot = spec.get("pivot", (size // 2, size - 4))
        (GFX / f"{rel}.anm2").write_text(anm2(png.name, size, spec["anims"], pivot))
    print(f"{len(ENTITIES)} entities written")


if __name__ == "__main__":
    main()
