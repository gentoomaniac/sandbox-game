"""Draws the proposed layout of Wehlsbüll (design/world/wehlsbuell.md) as a top-down PNG.

    .venv/bin/python design/world/wehlsbuell-layout.py

One block is one tile, `SCALE` pixels. The coast is drawn straight: u is tiles east of the sea
dyke, v tiles south of the village's middle row. The real coast wanders up to 8 tiles within the
village's rows (the site search takes only rows where it does), so the inland part is laid out
8 tiles or more behind the dyke.

The script also checks the layout: no two buildings or walls overlap, every door has its free
tile in front, and from every door one can walk to the Sielweg (the main lane) round the fences.
"""

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 10
U_MIN, U_MAX = -18, 62
V_MIN, V_MAX = -30, 36

# Building types: footprint (w, h), door offset (x, y), colour.
TYPES = {
    "hall_house": ((7, 5), (3, 4), (176, 96, 64)),
    "barn": ((6, 3), (2, 2), (140, 96, 70)),
    "coop": ((2, 2), (0, 1), (200, 160, 90)),
    "church": ((6, 4), (2, 3), (120, 120, 130)),
    "bell_frame": ((2, 2), (0, 1), (90, 70, 50)),
    "longhouse": ((7, 3), (3, 2), (190, 120, 60)),
    "kate": ((5, 3), (2, 2), (170, 80, 60)),
    "shack": ((3, 2), (1, 1), (150, 110, 70)),
    "fisher_hut": ((4, 2), (1, 1), (110, 90, 70)),
}

# (type, origin u, v, what it is, who lives there). Every plan building of the page.
BUILDINGS = [
    ("fisher_hut", -10, 10, "Ketels hut", "Momme, Inken"),
    ("hall_house", 24, -21, "Boysen farm", "Antje, Hinrich, Boy"),
    ("barn", 33, -20, "Boysen barn", ""),
    ("coop", 38, -17, "coop", ""),
    ("hall_house", 44, -19, "farm 2", ""),
    ("barn", 52, -18, "barn 2", ""),
    ("hall_house", 26, 19, "farm 3", ""),
    ("barn", 35, 21, "barn 3", ""),
    ("church", 27, -3, "church", ""),
    ("bell_frame", 35, -3, "bells", ""),
    ("kate", 14, -4, "parsonage", ""),
    ("longhouse", 46, 3, "Krug", ""),
    ("shack", 10, -6, "cottage", ""),
    ("shack", 10, 1, "cottage", ""),
    ("kate", 10, 4, "cottage", ""),
    ("kate", 10, 9, "Kerrin", "Kerrin"),
    ("kate", 10, 16, "cottage", ""),
    ("shack", 10, 22, "cottage", ""),
    ("kate", 45, 15, "mill house", "Ocke, Gesche"),
]

# Warften and the landing's: (centre u, v, radius u, radius v).
WARFTEN = [
    (-7, 12, 5.5, 4.0),
    (31, 0, 12.0, 8.0),
    (30, -17, 11.0, 6.0),
    (50, -15, 8.0, 6.0),
    (31, 23, 10.0, 6.0),
]
PONDS = [(22, -16, 2, 2)]

# Lanes, one tile wide: polylines through corner tiles.
LANES = [
    [(-3, 12), (60, 12)],  # Sielweg: landing, sluice, the whole village, the Geest
    [(9, -26), (9, 30)],  # Deichweg
    [(9, -13), (28, -13)],  # to the Boysen farm
    [(9, -1), (16, -1)],  # to the parsonage
    [(29, 7), (29, 12)],  # Kirchweg from the churchyard gate
    [(47, -12), (57, -12), (57, 12)],  # farm 2
    [(11, 24), (43, 24), (43, 12)],  # farm 3
    [(43, 18), (53, 18)],  # to the mill
    [(9, -23), (60, -23)],  # along the north fields
    [(9, 30), (30, 30)],  # to the south field
    [(43, 24), (51, 24), (51, 25)],  # to the Koppel
]

# Walls and fences: (kind, u0, v0, u1, v1, gaps as tiles).
FENCES = [
    ("wall", 22, -6, 40, 6, [(29, 6), (30, 6)]),  # churchyard
    ("fence", 21, -22, 40, -14, [(27, -14), (28, -14)]),  # Boysen yard
    ("fence", 43, -22, 58, -13, [(47, -13), (48, -13)]),  # farm 2 yard
    ("fence", 22, 17, 42, 26, [(29, 17), (30, 17), (22, 24), (42, 24)]),  # farm 3 yard
]

# Fields: u0, v0, u1, v1 and the gap tiles. A ditch where the ground is marsh (u <= MARSH_END),
# a Knick on the Geest, as the old generator did.
FIELDS = [
    (21, -28, 40, -24, [(30, -24), (31, -24)]),
    (43, -28, 58, -24, [(50, -24), (51, -24)]),
    (22, 31, 42, 34, [(30, 31), (31, 31)]),
    (46, 26, 59, 33, [(51, 26), (52, 26)]),
]
MARSH_END = 36

SQUARE = (43, 6, 55, 11)  # the town square by the Krug, kept free
MEETING = (49, 8)
MILL_SPOT = (51, 15, 57, 21)
LANDING_SPOT = (-12, 12)
JETTY = [(-13, 12), (-18, 12)]
SIEL = [(0, 14), (0, 15)]  # the Sielzug's gap in the dyke
SIELZUG = (1, 14, 28, 15)
TERRITORY = (-16, -28, 60, 34)

SKY = (236, 240, 232)
MUD = (205, 190, 160)
SALT = (150, 170, 140)
DYKE = (120, 90, 70)
MARSH = (176, 208, 140)
GEEST = (190, 212, 150)
WATER = (80, 130, 190)
WARFT = (150, 170, 100)
LANE = (222, 200, 150)
SQUARE_COLOUR = (236, 222, 170)
KNICK = (190, 110, 50)


def px(u: float, v: float) -> tuple[float, float]:
    return ((u - U_MIN) * SCALE, (v - V_MIN) * SCALE)


def tile_box(u0: int, v0: int, u1: int, v1: int) -> list[float]:
    """The pixel box of the tiles u0..u1, v0..v1 (both ends included)."""
    left, top = px(u0, v0)
    right, bottom = px(u1 + 1, v1 + 1)
    return [left, top, right, bottom]


def footprint(kind: str, u: int, v: int) -> set[tuple[int, int]]:
    (width, height), _, _ = TYPES[kind]
    return {(u + x, v + y) for x in range(width) for y in range(height)}


def door_front(kind: str, u: int, v: int) -> tuple[int, int]:
    _, (door_x, door_y), _ = TYPES[kind]
    return (u + door_x, v + door_y + 1)


def lane_tiles() -> set[tuple[int, int]]:
    tiles: set[tuple[int, int]] = set()
    for line in LANES:
        for (u0, v0), (u1, v1) in zip(line, line[1:]):
            for u in range(min(u0, u1), max(u0, u1) + 1):
                for v in range(min(v0, v1), max(v0, v1) + 1):
                    tiles.add((u, v))
    return tiles


def fence_tiles() -> set[tuple[int, int]]:
    tiles: set[tuple[int, int]] = set()
    for _, u0, v0, u1, v1, gaps in FENCES:
        ring = {(u, v) for u in range(u0, u1 + 1) for v in range(v0, v1 + 1)
                if u in (u0, u1) or v in (v0, v1)}
        tiles |= ring - set(gaps)
    return tiles


def field_tiles() -> tuple[set[tuple[int, int]], set[tuple[int, int]]]:
    """The ditch tiles and the Knick tiles of the fields' rings."""
    ditches: set[tuple[int, int]] = set()
    knicks: set[tuple[int, int]] = set()
    for u0, v0, u1, v1, gaps in FIELDS:
        ring = {(u, v) for u in range(u0, u1 + 1) for v in range(v0, v1 + 1)
                if u in (u0, u1) or v in (v0, v1)} - set(gaps)
        ditches |= {tile for tile in ring if tile[0] <= MARSH_END}
        knicks |= {tile for tile in ring if tile[0] > MARSH_END}
    return ditches, knicks


def check() -> None:
    covered: dict[tuple[int, int], str] = {}
    for kind, u, v, name, _ in BUILDINGS:
        for tile in footprint(kind, u, v):
            assert tile not in covered, f"{name} overlaps {covered[tile]} at {tile}"
            covered[tile] = name
    fences = fence_tiles()
    assert not fences & set(covered), f"a fence is in a building: {fences & set(covered)}"
    lanes = lane_tiles()
    # A lane over the Sielzug is a culvert: the water goes under it.
    water = {(u, v) for u in range(SIELZUG[0], SIELZUG[2] + 1) for v in range(SIELZUG[1], SIELZUG[3] + 1)}
    ditches, knicks = field_tiles()
    blocked = set(covered) | fences | (water - lanes) | ditches | knicks
    assert not (ditches | knicks) & (set(covered) | fences | lanes), "a field ring is on a building, fence or lane"
    assert not lanes & (set(covered) | fences), f"a lane runs through {lanes & blocked}"
    for kind, u, v, name, _ in BUILDINGS:
        front = door_front(kind, u, v)
        assert front not in blocked, f"the door of {name} is blocked at {front}"
    # Walk from every door to the Sielweg.
    for kind, u, v, name, _ in BUILDINGS:
        seen = {door_front(kind, u, v)}
        queue = deque(seen)
        while queue:
            u0, v0 = queue.popleft()
            for step in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                tile = (u0 + step[0], v0 + step[1])
                inside = U_MIN <= tile[0] <= U_MAX and V_MIN <= tile[1] <= V_MAX
                if inside and tile not in blocked and tile not in seen:
                    seen.add(tile)
                    queue.append(tile)
        assert (60, 12) in seen, f"nobody can walk from {name} to the Sielweg"
    # No field is shut in: from its gap one can walk to the Sielweg.
    for u0, v0, u1, v1, gaps in FIELDS:
        seen = set(gaps)
        queue = deque(seen)
        while queue:
            u, v = queue.popleft()
            for step in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                tile = (u + step[0], v + step[1])
                inside = U_MIN <= tile[0] <= U_MAX and V_MIN <= tile[1] <= V_MAX
                if inside and tile not in blocked and tile not in seen:
                    seen.add(tile)
                    queue.append(tile)
        assert (60, 12) in seen, f"the field at {u0}, {v0} is shut in"
    square = {(u, v) for u in range(SQUARE[0], SQUARE[2] + 1) for v in range(SQUARE[1], SQUARE[3] + 1)}
    assert not square & (set(covered) | fences | water | ditches | knicks), "the town square is not free"
    for spot in (MEETING, LANDING_SPOT):
        assert spot not in blocked, f"the spot {spot} is blocked"


def draw() -> Image.Image:
    width, height = (U_MAX - U_MIN) * SCALE, (V_MAX - V_MIN) * SCALE
    image = Image.new("RGB", (width, height), SKY)
    pen = ImageDraw.Draw(image)
    pen.rectangle(tile_box(U_MIN, V_MIN, -13, V_MAX), fill=MUD)
    pen.rectangle(tile_box(-12, V_MIN, -1, V_MAX), fill=SALT)
    pen.rectangle(tile_box(0, V_MIN, 0, V_MAX), fill=DYKE)
    pen.rectangle(tile_box(1, V_MIN, 36, V_MAX), fill=MARSH)
    pen.rectangle(tile_box(37, V_MIN, U_MAX, V_MAX), fill=GEEST)
    for u, v, radius_u, radius_v in WARFTEN:
        pen.ellipse([*px(u - radius_u, v - radius_v), *px(u + radius_u, v + radius_v)], fill=WARFT)
    pen.rectangle(tile_box(*SQUARE), fill=SQUARE_COLOUR)
    pen.rectangle(tile_box(*SIELZUG), fill=WATER)
    for u, v in SIEL:
        pen.rectangle(tile_box(u, v, u, v), fill=WATER)
    for u, v in lane_tiles():
        pen.rectangle(tile_box(u, v, u, v), fill=LANE)
    for u, v, w, h in PONDS:
        pen.rectangle(tile_box(u, v, u + w - 1, v + h - 1), fill=WATER)
    ditches, knicks = field_tiles()
    for tiles, colour in ((ditches, WATER), (knicks, KNICK)):
        for u, v in tiles:
            pen.rectangle(tile_box(u, v, u, v), fill=colour)
    pen.text(px(10, 13.2), "culvert", fill=(60, 40, 20))
    for u, v in fence_tiles():
        pen.rectangle(tile_box(u, v, u, v), fill=(250, 250, 250))
    u0, v0, u1, v1 = MILL_SPOT
    pen.rectangle(tile_box(u0, v0, u1, v1), outline=(60, 60, 60), width=2)
    pen.text(px(u0 + 1, v0 + 2), "post mill\nspot (free)", fill=(40, 40, 40))
    for u, v in JETTY[:1]:
        pen.rectangle(tile_box(JETTY[1][0], v, u, v), fill=(120, 80, 40))
    for kind, u, v, name, _ in BUILDINGS:
        pen.rectangle(tile_box(u, v, u + TYPES[kind][0][0] - 1, v + TYPES[kind][0][1] - 1),
                      fill=TYPES[kind][2], outline=(30, 20, 10))
        door = door_front(kind, u, v)
        pen.rectangle(tile_box(door[0], door[1] - 1, door[0], door[1] - 1), fill=(20, 20, 20))
        pen.text(px(u + 0.3, v + 0.2), name, fill=(255, 255, 255))
    pen.ellipse([*px(MEETING[0], MEETING[1]), *px(MEETING[0] + 1, MEETING[1] + 1)], fill=(220, 40, 40))
    pen.text(px(MEETING[0] + 1.5, MEETING[1]), "meeting place", fill=(120, 0, 0))
    pen.text(px(SQUARE[0] + 0.5, SQUARE[1] + 0.3), "town square (kept free)", fill=(90, 70, 20))
    pen.text(px(U_MAX - 12, 13), "track to the camp ->", fill=(90, 60, 20))
    pen.text(px(LANDING_SPOT[0] - 1, LANDING_SPOT[1] + 1), "landing", fill=(30, 30, 80))
    pen.text(px(1, 16.5), "Siel", fill=(30, 30, 100))
    pen.text(px(2, -28), "sea dyke at u = 0 (drawn straight)", fill=(60, 40, 30))
    pen.rectangle(tile_box(*TERRITORY[:2], TERRITORY[2], TERRITORY[3]), outline=(200, 40, 40), width=2)
    pen.text(px(TERRITORY[0] + 1, TERRITORY[1] + 0.5), "Wehlsbuell's land", fill=(200, 40, 40))
    scale_left, scale_top = px(U_MIN + 1, V_MAX - 2)
    pen.rectangle([scale_left, scale_top, scale_left + 10 * SCALE, scale_top + 5], fill=(0, 0, 0))
    pen.text((scale_left, scale_top + 8), "10 tiles", fill=(0, 0, 0))
    return image


if __name__ == "__main__":
    check()
    draw().save(Path(__file__).with_suffix(".png"))
    print("ok:", len(BUILDINGS), "buildings")
