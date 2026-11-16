"""The identity and order of the art both generators draw, and the check that every picture has
exactly one source.

The new art (generate.py) and the classic art (classic/generate.py) each draw their own pictures
with their own code but declare the same things here, so a new object or piece of furniture is
added to this list and to the module that draws it, and to no assembly list.

A generator collects the pictures of its families in a dict per source and merges them with
`merge`, which refuses a name two sources both draw and names both; `in_declared_order` then lays
the merged pictures out in the declared order and refuses one that is missing or not declared.
"""

# The rows of assets/objects.png, by art kind. `atlas_row` of each type in
# game/state/world_objects/ is its number here, and tests/test_object_atlas.gd checks it against
# assets/objects_rows.txt, which is written from this list. A tree's trunks are two rows, the long
# trunk and then the short one; its `trunk` in world_objects/trees.gd names the first. The notes
# say how many variants (cells) a row has.
OBJECT_KINDS = (
    "oak",  # 0: 3 variants
    "stone",  # 1: 2 variants
    "fireplace",  # 2: 1, then the same with the fire out
    "sleeping_bag",  # 3: 1 variant
    "spruce",  # 4: 3 variants
    "pine",  # 5: 3 variants
    "dead_tree",  # 6: 3 variants
    "berry_bush",  # 7: 3, then the same 3 picked
    "shrub",  # 8: 3 variants
    "sapling",  # 9: 3 variants
    "fern",  # 10: 3; the game type is fern_bush, the art kind keeps its old name
    "boulder",  # 11: 2 variants
    "stump",  # 12: 2 variants
    "tall_grass",  # 13: 3, then the same 3 mown
    "oak_trunk",  # 14: 2 variants
    "oak_short_trunk",  # 15: 2 variants
    "spruce_trunk",  # 16: 2 variants
    "spruce_short_trunk",  # 17: 2 variants
    "pine_trunk",  # 18: 2 variants
    "pine_short_trunk",  # 19: 2 variants
    "dead_tree_trunk",  # 20: 2 variants
    "dead_tree_short_trunk",  # 21: 2 variants
    "willow_trunk",  # 22: 2 variants
    "willow_short_trunk",  # 23: 2 variants
    "reeds",  # 24: 3, then the same 3 cut
    "dead_stump",  # 25: 2 variants
    "chest",  # 26: 1 variant
    "knick",  # 27: 3 variants of 16, one per connection mask, see boundaries.py
    "wattle_fence",  # 28: 16, one per connection mask
    "stone_wall",  # 29: 3 variants of 16
    "dyke",  # 30: 16, one per connection mask, then 12 corners crossing a side on the slant, see slants.py
    "willow",  # 31: 3 variants
    "beech",  # 32: 3 variants
    "beech_trunk",  # 33: 2 variants
    "beech_short_trunk",  # 34: 2 variants
    "birch",  # 35: 3 variants
    "birch_trunk",  # 36: 2 variants
    "birch_short_trunk",  # 37: 2 variants
    "alder",  # 38: 3 variants
    "alder_trunk",  # 39: 2 variants
    "alder_short_trunk",  # 40: 2 variants
    "workbench",  # 41: 1 variant
    "carved_chest",  # 42: 1 variant
    "kiln",  # 43: 1 variant
    "oven",  # 44: 1 variant
    "ewer",  # 45: 1, three cells wide
    "grave",  # 46: 3 variants
    "jetty",  # 47: 16, one per connection mask, see landing.py
    "rowing_boat",  # 48: 1 variant
    "net_frame",  # 49: 1 variant
    "eel_traps",  # 50: 1 variant
    "draw_well",  # 51: 1 variant
    "trough",  # 52: 4, its fills: empty, low, half, full, see yard.py
    "hay_rack",  # 53: 4, the same
    "feed_trough",  # 54: 4, the same: the trough with feed in it
    "pen_fence",  # 55: 16, one per connection mask, see pen.py
    "pen_gate",  # 56: 16, the same
    "pig_shelter",  # 57: 1 variant
    "pen_gate_open",  # 58: 16, the gate swung open
    "scarecrow",  # 59: 3 frames: still, then blown by the wind, see scarecrow.py
    "plank_walk",  # 60: 4 variants of 16, one per connection mask: full-tile ground pieces that run on into the ways beside them, see ways.py
    "stone_path",  # 61: 3 variants of 16, the same
    "way_edge",  # 62: 16, one per mask of the sides with a way beside them: not an object, drawn on the free tiles beside ways, see ways.py
    "market_stall",  # 63: 1, see stall.py
    "dead_oak",  # 64-77 the dead trees of each kind (3 variants each), then the half-dead ones (2 each), see snags.py
    "dead_beech",
    "dead_birch",
    "dead_alder",
    "dead_willow",
    "dead_pine",
    "dead_spruce",
    "half_dead_oak",
    "half_dead_beech",
    "half_dead_birch",
    "half_dead_alder",
    "half_dead_willow",
    "half_dead_pine",
    "half_dead_spruce",
    "notice_board",  # 78: 1, see notice_board.py
    "sales_cart",  # 79: 1, see sales_cart.py
    "dyke_low",  # 80: 28, as the dyke: its look under 1.5 m, see boundaries.DYKE_LOOKS
    "dyke_high",  # 81: 28, the same: its look over 2.8 m
    "dyke_torn",  # 82: 28, the same: its torn crest while the sea has damaged it, see boundaries.torn_dyke
)


# The furniture of the interiors, by name. The marker tiles of assets/interior.png and the files
# follow this order, and the tile ids of the tileset (maps/interiors/*.tsx) are counted in it, so
# new pieces go at the end.
FURNITURE = (
    "bed",
    "table",
    "stool",
    "chest",
    "hearth",
    "window",
    "sleeping_mat",
    "box_bed",
    "bench",
    "stall_partition",
    "hay_pile",
    "barrel",
    "sacks",
    "crate",
    "plate_rack",
    "wall_bench",
)


class DuplicateContribution(ValueError):
    """Two sources draw the same name."""


def merge(contributions):
    """The names of every source in one dict. `contributions` maps a source's name (for the
    error message) to its dict; a name that two sources draw raises, naming both."""
    merged = {}
    source_of = {}
    for source, named in contributions.items():
        for name, value in named.items():
            if name in merged:
                raise DuplicateContribution(f"{name!r} is drawn by both {source_of[name]} and {source}")
            merged[name] = value
            source_of[name] = source
    return merged


def in_declared_order(declared, drawn, what):
    """`drawn` (a dict by name) as (name, value) pairs in the order of `declared`. A name that is
    declared and not drawn, or drawn and not declared, raises."""
    missing = [name for name in declared if name not in drawn]
    undeclared = [name for name in drawn if name not in declared]
    if missing or undeclared:
        raise ValueError(f"{what}: declared but not drawn: {missing}; drawn but not declared: {undeclared}")
    return [(name, drawn[name]) for name in declared]
