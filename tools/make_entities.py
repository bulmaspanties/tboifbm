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


ENTITIES = {
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
