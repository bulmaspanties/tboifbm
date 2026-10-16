"""Render Gridiron's item/trinket/tear sprites from the pixel maps below.

Each sprite is a list of rows; every character is one pixel looked up in
PALETTE ('.' is transparent). Sprites marked `mirror` only list the left half
and are mirrored to the right. Edit the maps and rerun:

    python3 tools/make_sprites.py      (from the repo root; needs Pillow)
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
GFX = ROOT / "resources/gfx"

PALETTE = {
    ".": (0, 0, 0, 0),
    "K": (20, 12, 12, 255),      # outline
    # helmet red
    "r": (120, 15, 22, 255),
    "R": (190, 32, 42, 255),
    "S": (225, 60, 68, 255),
    "H": (250, 150, 150, 255),
    # whites / greys
    "W": (248, 248, 244, 255),
    "w": (214, 214, 208, 255),
    "v": (168, 168, 162, 255),
    "G": (196, 200, 210, 255),   # facemask
    "g": (118, 120, 132, 255),
    "D": (48, 20, 22, 255),      # dark interior
    # team blue / gold
    "b": (24, 42, 112, 255),
    "B": (40, 74, 170, 255),
    "L": (82, 122, 214, 255),
    "Y": (244, 204, 52, 255),
    "y": (196, 150, 30, 255),
    # blacks (eye black, cleats)
    "k": (30, 30, 36, 255),
    "n": (58, 58, 68, 255),
    "N": (98, 98, 110, 255),
    # football leather / laces
    "f": (92, 46, 22, 255),
    "F": (140, 74, 36, 255),
    "E": (178, 104, 56, 255),
    # kicking tee orange
    "o": (186, 78, 18, 255),
    "O": (238, 122, 32, 255),
    "P": (255, 176, 86, 255),
}

SPRITES = {}

# --- Football Helmet (3/4 view facing right) ----------------------------------
SPRITES["items/collectibles/football_helmet.png"] = dict(rows=[
    "................................",
    "................................",
    "...........KKKKKKKK.............",
    ".........KKWWWWWWWWKK...........",
    "........KWWSSSSSSSSWWK..........",
    ".......KWSHHSSSSSSSSSWK.........",
    "......KWSHHSSSSSSSSSSSWK........",
    ".....KWSHSSSSSSSSSSSSSSWK.......",
    ".....KWSSSSSSSSSSSSSSSSSWK......",
    "....KWRSSSSSSSSSSSSSSSSSSWK.....",
    "....KWRSSSSSSSSSSSSSSSSSSSK.....",
    "....KRRSSSSSSSSSSSSSSSSSSSK.....",
    "...KRRRSSSSSSSSSSSSSSSSSSSKK....",
    "...KRRSSSSSKKKKSSSSSSSSSKKDKKK..",
    "...KRRSSSSKggggKSSSSSSSKDDDGGK..",
    "...KRRSSSSKgDDgKSSSSSSKDDDGKGK..",
    "...KrRRSSSKgDDgKSSSSSSKGGGGGGK..",
    "...KrRRSSSSKggKSSSSSSSKDDDGKGK..",
    "...KrrRRSSSSKKSSSSSSSSKDDDGKGK..",
    "....KrRRRSSSSSSSSSSSSSKGGGGGGK..",
    "....KrrRRRSSSSSSSSSSSKKDDDGKGK..",
    ".....KrrRRRRSSSSSSSSSKDDDDGKGK..",
    ".....KKrrrRRRRRRRRRRRKGGGGGGK...",
    ".......KKrrrrrRRRRRRRKDDDGKK....",
    ".........KKKKrrrrrrrrKGGGK......",
    "............KKKKKKKKKKKKK.......",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
])

# --- Shoulder Pads (front view, mirrored) -------------------------------------
SPRITES["items/collectibles/shoulder_pads.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "................",
    "................",
    "......KKKKKKK...",
    "....KKWWWWWWWKK.",
    "...KWWWWWWWWWwwK",
    "..KWWWWWWWwwwwwK",
    ".KWWWWWWwwwwwwKD",
    ".KWWWWwwwwwwwwKD",
    "KWWWwwwwwwwwwwKD",
    "KWwwwwwwwwwwvvKK",
    "KwwwwwwwwwwvvKBB",
    "KvwwwwwwwvvvKBBB",
    ".KvvwwwvvvvKKBBB",
    "..KKvvvvKKKLBBBB",
    "....KKKKBLLBBBBB",
    "......KbBLBBBBBB",
    "......KbBBBBBBBB",
    "......KbBBBBBBBB",
    "......KbYYYYYYYY",
    "......KbBBBBBBBB",
    "......KbbBBBBBBB",
    "......KbbBBBBBBB",
    "......KbbBBBBBBB",
    ".......KKKKKKKKK",
    "................",
    "................",
    "................",
    "................",
    "................",
])

# --- Team Jersey (front view, mirrored; number drawn on top) -----------------
SPRITES["items/collectibles/team_jersey.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "........KKKK....",
    "......KKBBBKKKKK",
    "....KKBBBBBBYYYY",
    "...KBBLBBBBBKYYK",
    "..KBLLBBBBBBBKKB",
    ".KBLLBBBBBBBBBBB",
    "KBLLBBBBBBBBBBBB",
    "KYYBBBBBBBBBBBBB",
    "KYYKBBBBBBBBBBBB",
    ".KKKBBBBBBBBBBBB",
    "...KBBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbBBBBBBBBBBB",
    "...KbbBBBBBBBBBB",
    "...KbbBBBBBBBBBB",
    "...KbbBBBBBBBBBB",
    "...KYYYYYYYYYYYY",
    "...KyyyyyyyyyyyY",
    "....KKKKKKKKKKKK",
    "................",
    "................",
    "................",
    "................",
    "................",
], overlay=[
    # big white "7" with outline, placed over the chest
    (11, 10, [
        "KKKKKKKKKK",
        "KWWWWWWWWK",
        "KWWWWWWWWK",
        "KKKKKKWWWK",
        "....KWWWKK",
        "...KWWWK..",
        "...KWWWK..",
        "..KWWWK...",
        "..KWWWK...",
        "..KWWWK...",
        "..KKKKK...",
    ]),
])

# --- Football Cleats (side view facing right) ---------------------------------
SPRITES["items/collectibles/football_cleats.png"] = dict(rows=[
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "....KKKKKKKK....................",
    "...KnnnnnnnnK...................",
    "...KnNNNNNNnK...................",
    "...KnkkkkkknKK..................",
    "...KnkkWkkkknnK.................",
    "...KnkkkWkkkknK.................",
    "...KnkkWkkkkknnKK...............",
    "...KnkkkWkkkkknnnKK.............",
    "...KnkkWkkkkkkkknnnKKK..........",
    "...KnkkkkkkkkkkkkkknnnKKK.......",
    "...KnkkkkkkkkkkkkkkkkknnnKK.....",
    "...KnkkkkkkkkkkkkkkkkkkkknnK....",
    "...KnkkkkkkRRRRRRRkkkkkkkknK....",
    "...KnkkkkRRRSSSSSRRRkkkkkkkK....",
    "...KnkkkkkkkkkkkkkkkSRkkkkkK....",
    "...KnnkkkkkkkkkkkkkkkkkkkkkK....",
    "...KKKKKKKKKKKKKKKKKKKKKKKKK....",
    "...KWWWWWWWWWWWWWWWWWWWWWWWK....",
    "...KwwwwwwwwwwwwwwwwwwwwwwwK....",
    "....KKKKKKKKKKKKKKKKKKKKKKK.....",
    ".....KWWK..KWWK..KWWK..KWWK.....",
    ".....KwwK..KwwK..KwwK..KwwK.....",
    "......KK....KK....KK....KK......",
    "................................",
    "................................",
    "................................",
])

# --- Eye Black (grease stick + two swipes) ------------------------------------
SPRITES["items/collectibles/eye_black.png"] = dict(rows=[
    "................................",
    "................................",
    "................................",
    "................................",
    "................KKKKKKKKKKKK....",
    "...............KkkNNnkkkkkkkK...",
    "..............KkkNkkkkkkkkkK....",
    ".............KkkkkkkkkkkkkK.....",
    "..............KKKKKKKKKKKK......",
    "................................",
    "....KKKKKK......................",
    "...KnnNNnnK.....................",
    "...KkkkkkkK.....KKKKKKKKKKKK....",
    "...KkkkkkkK....KkkNNnkkkkkkkK...",
    "...KKKKKKKK...KkkNkkkkkkkkkK....",
    "...KGGGGGgK..KkkkkkkkkkkkkK.....",
    "...KGWGGGgK...KKKKKKKKKKKK......",
    "...KGWGGGgK.....................",
    "...KGWGGGgK.....................",
    "...KGGGGGgK.....................",
    "...KRRRRRrK.....................",
    "...KSSSSRrK.....................",
    "...KRRRRRrK.....................",
    "...KGGGGGgK.....................",
    "...KGWGGGgK.....................",
    "...KGGGGGgK.....................",
    "...KGGGGGgK.....................",
    "....KKKKKK......................",
    "................................",
    "................................",
    "................................",
    "................................",
])

# --- Padded Pants (trinket, mirrored) -----------------------------------------
SPRITES["items/trinkets/padded_pants.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "................",
    "......KKKKKKKKKK",
    "......KffFFFFFFF",
    "......KKKKKKKKYK",
    "......KBWWWWWWWW",
    "......KBWWWWWWWW",
    "......KBWWWWWWWW",
    "......KBWWWWWWww",
    "......KBWWWWWWwK",
    "......KBWwwwWWwK",
    "......KBwvvvwWwK",
    "......KBwvvvwWwK",
    "......KBwvvvwWwK",
    "......KBWwwwWWwK",
    "......KBWWWWWWwK",
    "......KBWWWWWwK.",
    "......KBWwwwWwK.",
    "......KBwvvvwwK.",
    "......KBwvvvwwK.",
    "......KBWwwwWwK.",
    "......KBWWWWwwK.",
    "......KKKKKKKKK.",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
])

# --- Receiver Gloves (palms out, mirrored) -------------------------------------
SPRITES["items/collectibles/receiver_gloves.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "................",
    "................",
    ".....KK.KK......",
    "....KWwKWwK.....",
    "..KKKWwKWwKKK...",
    ".KWwKWwKWwKWwK..",
    ".KWwKWwKWwKWwK..",
    ".KWwKWwKWwKWwK..",
    ".KWwKWwKWwKWwK..",
    ".KWwKWwKWwKWwK..",
    ".KWwwwwwwwwwwKK.",
    ".KWwvvvvvvvwwwwK",
    ".KWwvgvvvgvwwwwK",
    ".KWwvvvvvvvwwwwK",
    ".KWwvvgvvgvwwwK.",
    ".KWwvvvvvvvwwK..",
    ".KWwwvvvvvwwwK..",
    ".KWwwwwwwwwwwK..",
    ".KKKKKKKKKKKKK..",
    ".KLBBBBBBBBBbK..",
    ".KYYYYYYYYYYYK..",
    ".KLBBBBBBBBBbK..",
    ".KKKKKKKKKKKKK..",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
])

# --- Mouthguard (top view, mirrored) ------------------------------------------
SPRITES["items/collectibles/mouthguard.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "........KKKKKKKK",
    ".....KKKLLLLLLLL",
    "...KKLLLBBBBBBBB",
    "..KLLBBBBbBBbBBb",
    ".KLBBBBBKKKKKKKK",
    ".KLBBBKK........",
    "KLBBBK..........",
    "KLBbBK..........",
    "KLBBBK..........",
    "KLBbBK..........",
    "KLBBBK..........",
    "KBBbbK..........",
    ".KBbK...........",
    "..KK............",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
])

# --- Kicking Tee (ball standing in an orange tee, mirrored) -------------------
SPRITES["items/collectibles/kicking_tee.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "..............KK",
    "............KKFF",
    "...........KfFFE",
    "..........KfFFEE",
    "..........KfFFEW",
    ".........KfFFEWW",
    ".........KfFFEEW",
    ".........KfFFEWW",
    ".........KfFFEEW",
    ".........KfFFEWW",
    ".........KfFFEEW",
    ".........KfFFEWW",
    ".........KfFFEEW",
    "..........KfFFEE",
    "..........KffFFE",
    ".......KK..KffFF",
    ".......KoK..Kfff",
    ".......KoOK..KKK",
    ".......KoOOKKKKK",
    "......KooOOOOOOO",
    ".....KooOOOOOPPP",
    "....KooOOOOOOOOO",
    "....KoooooOOOOOO",
    "....KKKKKKKKKKKK",
    "................",
    "................",
    "................",
    "................",
    "................",
])

# --- Pigskin (a big football, mirrored) ---------------------------------------
SPRITES["items/collectibles/pigskin.png"] = dict(mirror=True, rows=[
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "........KKKKKKKK",
    ".....KKKFFFFFFFF",
    "...KKfFFWFEEEEEE",
    "..KfFFFWEEEEEEEE",
    ".KfFFFFWEEEEKWKW",
    ".KfFFFFWEEEWWWWW",
    "KffFFFFWEEEEKWKW",
    "KffFFFFWEEEEEEEE",
    "KffFFFFWEEEEEEEE",
    ".KffFFFWFFFFFFFF",
    ".KfffFFWFFFFFFFF",
    "..KfffFWFFFFFFFF",
    "...KKffWffffffff",
    ".....KKKffffffff",
    "........KKKKKKKK",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
])

# --- Football tear: 4-frame spiral strip (16x16 each, nose pointing +X) -----
# Lua rotates the sprite to the tear's velocity; the frames roll the laces.
FOOTBALL_FRAMES = [
    [  # laces facing the camera
        "................",
        "................",
        "................",
        "....KKKKKKKK....",
        "..KKFFFFFFFFKK..",
        ".KfFFEEEEEEFFfK.",
        "KfFFEEWEWEWEFFfK",
        "KfFFFWWWWWWWFFfK",
        "KffFFFWEWEWFFFfK",
        ".KffFFFFFFFFFfK.",
        "..KKffffffffKK..",
        "....KKKKKKKK....",
        "................",
        "................",
        "................",
        "................",
    ],
    [  # laces rolling up
        "................",
        "................",
        "................",
        "....KKKKKKKK....",
        "..KKFWEWEWEFKK..",
        ".KfFFWWWWWWWFfK.",
        "KfFFEFWEWEWFEFfK",
        "KfFFEEEEEEEEFFfK",
        "KffFFFFFFFFFFFfK",
        ".KffFFFFFFFFFfK.",
        "..KKffffffffKK..",
        "....KKKKKKKK....",
        "................",
        "................",
        "................",
        "................",
    ],
    [  # laces on the far side
        "................",
        "................",
        "................",
        "....KKKKKKKK....",
        "..KKFFFFFFFFKK..",
        ".KfFFEEEEEEFFfK.",
        "KfFFEEEEEEEEFFfK",
        "KfFFFEEEEEEFFFfK",
        "KffFFFFFFFFFFFfK",
        ".KffffFFFFffffK.",
        "..KKffffffffKK..",
        "....KKKKKKKK....",
        "................",
        "................",
        "................",
        "................",
    ],
    [  # laces rolling back in from below
        "................",
        "................",
        "................",
        "....KKKKKKKK....",
        "..KKFFFFFFFFKK..",
        ".KfFFEEEEEEFFfK.",
        "KfFFEEEEEEEEFFfK",
        "KfFFFEEEEEEFFFfK",
        "KffFFFWEWEWFFFfK",
        ".KffFWWWWWWWFfK.",
        "..KKfWEWEWEfKK..",
        "....KKKKKKKK....",
        "................",
        "................",
        "................",
        "................",
    ],
]
SPRITES["tears/gridiron_football.png"] = dict(size=16, frames=FOOTBALL_FRAMES)


def render_rows(rows, size, mirror=False, overlay=()):
    if mirror:
        rows = [r + r[::-1] for r in rows]
    if len(rows) != size:
        raise ValueError(f"expected {size} rows, got {len(rows)}")
    img = Image.new("RGBA", (size, size), PALETTE["."])
    px = img.load()
    for y, row in enumerate(rows):
        if len(row) != size:
            raise ValueError(f"row {y} is {len(row)} wide: {row!r}")
        for x, ch in enumerate(row):
            px[x, y] = PALETTE[ch]
    for ox, oy, patch in overlay:
        for y, row in enumerate(patch):
            for x, ch in enumerate(row):
                if ch != ".":
                    px[ox + x, oy + y] = PALETTE[ch]
    return img


def render(spec):
    size = spec.get("size", 32)
    frames = spec.get("frames") or [spec["rows"]]
    strip = Image.new("RGBA", (size * len(frames), size), PALETTE["."])
    for i, rows in enumerate(frames):
        frame = render_rows(rows, size, spec.get("mirror", False), spec.get("overlay", ()))
        strip.paste(frame, (i * size, 0))
    return strip


def main():
    for rel, spec in SPRITES.items():
        out = GFX / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        render(spec).save(out)
    print(f"{len(SPRITES)} sprites written")


if __name__ == "__main__":
    main()
