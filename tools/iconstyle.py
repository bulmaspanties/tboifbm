"""Shared finishing pass that makes generated item icons sit with the vanilla art.

Isaac's item sprites share a look: one heavy near-black outline around the whole
silhouette, slightly muted colours, and rounded volume (a lit top-left rim and a
shaded bottom-right rim). `finish()` applies that to a flat-drawn icon. Every
generator that writes an item/trinket icon calls it right before saving, so the
pass runs exactly once per build.
"""
import colorsys

from PIL import Image

OUTLINE = (22, 14, 14, 255)
DARK_LUMA = 45          # border pixels darker than this already read as an outline
SATURATION = 0.92
VALUE = 0.97
RIM_LIGHT = 1.10
RIM_SHADE = 0.86

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def _luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def _scale(p, k):
    return tuple(max(0, min(255, round(c * k))) for c in p[:3]) + (p[3],)


def _mute(p):
    h, s, v = colorsys.rgb_to_hsv(*(c / 255 for c in p[:3]))
    r, g, b = colorsys.hsv_to_rgb(h, s * SATURATION, v * VALUE)
    return (round(r * 255), round(g * 255), round(b * 255), p[3])


def finish(img):
    img = img.convert("RGBA")
    w, h = img.size
    src = img.load()
    solid = [[src[x, y][3] > 0 for x in range(w)] for y in range(h)]

    def is_solid(x, y):
        return 0 <= x < w and 0 <= y < h and solid[y][x]

    def is_line(x, y):
        return is_solid(x, y) and _luma(src[x, y]) < DARK_LUMA

    # the outer outline only: dark pixels touching the air (interior detail lines don't count)
    outer = {(x, y) for y in range(h) for x in range(w) if is_line(x, y)
             and any(not is_solid(x + dx, y + dy) for dx, dy in N4)}

    def is_edge(x, y):
        return not is_solid(x, y) or (x, y) in outer

    out = img.copy()
    px = out.load()

    for y in range(h):
        for x in range(w):
            if not solid[y][x]:
                continue
            p = src[x, y]
            if _luma(p) < DARK_LUMA:
                px[x, y] = OUTLINE[:3] + (p[3],)    # unify every dark line to one ink
                continue
            q = _mute(p)
            # rim light where the top-left edge meets the outline / air,
            # rim shade along the bottom-right edge
            if is_edge(x, y + 1) or is_edge(x + 1, y):
                q = _scale(q, RIM_SHADE)
            elif is_edge(x, y - 1) or is_edge(x - 1, y):
                q = _scale(q, RIM_LIGHT)
            px[x, y] = q

    # close the silhouette: any light pixel on the edge of the shape gets ink outside it
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                continue
            for dx, dy in N4:
                if is_solid(x + dx, y + dy) and not is_line(x + dx, y + dy):
                    px[x, y] = OUTLINE
                    break
    return out


def finish_strip(img, frame):
    """Finish a horizontal strip frame by frame so outlines never bleed between frames."""
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for i in range(img.width // frame):
        box = (i * frame, 0, (i + 1) * frame, img.height)
        out.paste(finish(img.crop(box)), box[:2])
    return out
