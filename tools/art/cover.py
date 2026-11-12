"""The textures of the seasonal overlays: fallen leaves, frost and snow lie over the ground and
the objects pixel by pixel, where the ground shader finds a threshold below the cover (see
game/state/ground_cover.gd for the rule and docs/plans/185-season-overlays.md).

- `ground_noise` is the threshold map: its histogram is even, so a cover of 0.3 covers 30 % of the
  pixels, in organic patches a few tiles across with a grain of single pixels.
- `leaf_litter_image` is a field of single fallen leaves in palette colours; each leaf has a rank,
  so a thin litter shows the leaves with the lowest ranks and the rest arrive one by one.
- `cover_cells` makes of an object's picture in a look (snow, frost) and its picture without the
  cover the pixels the look adds, which the game lays over the picture of the season. `ranked`
  turns them into the textures the shader reads (pack.py).

The textures hold data, not art: a rank is stored in the alpha channel (1 to 255, 0 is nothing),
so the folder of the textures is left out of the palette check (see palette.DATA_TEXTURES).
"""

import numpy as np
from PIL import Image

import palette
import seasons

# The looks of the cover an object atlas has besides the seasons' (see `object_cover_looks`): the
# snow, whose rank grows from the top of the picture down, and the frost, ranked by noise alone.
COVER_LOOKS = ("snow_cover", "frost_cover")
TOP_DOWN_LOOKS = ("snow_cover",)
# The seed of the ranks of a sheet; each cell adds its place in the sheet, so redrawing one object
# does not reshuffle the others.
RANK_SEED = 185
# How many tiles the repeating textures are across.
NOISE_TILES = 16
LEAF_TILES = 16
# Value noise: the size of the lattice cells in tiles, with their weights, and the weight of the
# grain of single pixels.
NOISE_SCALES = ((4.0, 0.55), (1.5, 0.3))
GRAIN_WEIGHT = 0.08
# Fallen leaves per tile on the leaf texture, and the colours they come in, each with the darker
# colour of the shaded pixel of the leaf.
LEAVES_PER_TILE = {32: 20, 16: 10}
LEAF_SHADES = {
    "leaf_orange": "ochre",
    "ochre": "ochre_dark",
    "rust": "rust_dark",
    "ochre_dark": "umber",
    "umber": "russet_deep",
    "soil_light": "umber",
    "red_light": "rust",
}
# The shapes of a leaf: (dx, dy, is_shaded) pixels. At 16 px per tile a leaf is one pixel or two.
LEAF_SHAPES_32 = (
    ((0, 0, 0), (1, 0, 0), (2, 1, 1)),
    ((0, 1, 0), (1, 0, 0), (2, 0, 1)),
    ((0, 0, 0), (0, 1, 0), (1, 2, 1)),
    ((0, 0, 0), (1, 0, 0), (1, 1, 1), (2, 1, 1)),
    ((0, 0, 0), (1, 1, 1)),
)
LEAF_SHAPES_16 = (((0, 0, 0),), ((0, 0, 0), (1, 0, 1)), ((0, 0, 0), (0, 1, 1)))
# How much of the rank of the snow on an object is pixel noise; the rest is the pixel's height in
# its picture, so the snow grows from the top down.
RANK_NOISE = 0.25


def _periodic_value_noise(rng, side, cells):
    """Smooth noise on a side x side grid that wraps around, from a lattice of cells x cells."""
    lattice = rng.random((cells, cells))
    positions = np.arange(side) * cells / side
    low = positions.astype(int)
    fraction = positions - low
    fraction = fraction * fraction * (3 - 2 * fraction)
    along_x = lattice[:, low % cells] * (1 - fraction) + lattice[:, (low + 1) % cells] * fraction
    return along_x[low % cells] * (1 - fraction)[:, None] + along_x[(low + 1) % cells] * fraction[:, None]


def _evened(values):
    """The ranks of the values, 0 to 1, spread evenly: their histogram is flat."""
    ranks = np.empty(values.size)
    ranks[np.argsort(values, axis=None, kind="stable")] = np.arange(values.size)
    return (ranks / values.size).reshape(values.shape)


def ground_noise(tile_size, seed=185):
    """The threshold map: an RGBA picture NOISE_TILES tiles across that repeats, whose red, green
    and blue channels are three independent maps (snow, frost and a spare one), alpha opaque."""
    side = NOISE_TILES * tile_size
    rng = np.random.default_rng(seed)
    channels = []
    for _ in range(3):
        mixed = rng.random((side, side)) * GRAIN_WEIGHT
        for tiles, weight in NOISE_SCALES:
            mixed += weight * _periodic_value_noise(rng, side, max(2, round(NOISE_TILES / tiles)))
        channels.append(np.round(_evened(mixed) * 255).astype(np.uint8))
    picture = np.dstack([*channels, np.full((side, side), 255, np.uint8)])
    return Image.fromarray(picture, "RGBA")


def rank_alpha(rank):
    """A rank from 0 to 1 as an alpha value, 1 to 255."""
    return 1 + round(min(max(rank, 0.0), 1.0) * 254)


def leaf_litter(tile_size, seed=185):
    """The field of fallen leaves, LEAF_TILES tiles across, as an RGBA picture that repeats: each
    leaf pixel in a palette colour, its leaf's rank in alpha. No two leaves overlap."""
    side = LEAF_TILES * tile_size
    shapes = LEAF_SHAPES_32 if tile_size >= 32 else LEAF_SHAPES_16
    rng = np.random.default_rng(seed)
    colours = list(LEAF_SHADES)
    image = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    taken = set()
    count = LEAF_TILES * LEAF_TILES * LEAVES_PER_TILE[tile_size]
    # Each leaf has a cell of a jittered grid, so they spread evenly.
    cells = int(np.ceil(np.sqrt(count)))
    cell_size = side / cells
    for index in rng.permutation(cells * cells)[:count]:
        x0 = int((index % cells + rng.random()) * cell_size)
        y0 = int((index // cells + rng.random()) * cell_size)
        shape = shapes[rng.integers(len(shapes))]
        sign = -1 if rng.random() < 0.5 else 1
        pixels = [((x0 + sign * dx) % side, (y0 + dy) % side, shaded) for dx, dy, shaded in shape]
        base = colours[rng.integers(len(colours))]
        alpha = rank_alpha(rng.random())
        if any((x, y) in taken for x, y, _ in pixels):
            continue
        for x, y, shaded in pixels:
            name = LEAF_SHADES[base] if shaded else base
            image.putpixel((x, y), (*bytes.fromhex(palette.PALETTE[name]), alpha))
            taken.add((x, y))
    return image


def cover_cells(with_cover, without_cover):
    """The pixels a look adds to a picture: those of `with_cover` (rows of colour names) that are
    drawn and differ from `without_cover`, everything else clear."""
    return [
        [name if name is not None and name != base else None for name, base in zip(row, base_row)]
        for row, base_row in zip(with_cover, without_cover)
    ]


def object_cover_looks(cells_by_look):
    """The snow and frost an object atlas adds to its pictures, as the looks COVER_LOOKS: for each
    entity (`cells_by_look[look][i]` are the cells of entity i in a look), the pixels that its
    snow and frost looks add to its bare picture: a leafless tree's own, and for everything else
    the summer picture but for its ground shadow."""
    result = {look: [] for look in COVER_LOOKS}
    for index in range(len(cells_by_look["bare"])):
        without_cover = cells_by_look["bare"][index]
        for look, covered in zip(COVER_LOOKS, ("snow", "frost")):
            result[look].append(
                [cover_cells(cell, base) for cell, base in zip(cells_by_look[covered][index], without_cover)]
            )
    return result


def house_cover(picture, snowy):
    """The pixels that snow adds to the roof of a house picture (rows of colour names; `snowy` are
    the pixels of its roof, see seasons.house) over the roof without snow, as a picture of the
    house's size; `ranked` gives them the rank from the ridge down."""
    return cover_cells(seasons.house("snow", picture, snowy), seasons.house("bare", picture, snowy))


def is_roof_snow(relative):
    """Whether the file at `relative` (under art/generated/) is the snow of a house's roof."""
    return relative.startswith("buildings/") and "_snow_cover_" in relative


def ranked(picture, cell_width, cell_height, is_top_down):
    """A sheet of cover cells with each drawn pixel's rank in its alpha: from the pixel's height in
    its cell's drawing (the top has the lowest rank, so it is covered first) and noise if
    `is_top_down`, from noise alone otherwise."""
    pixels = np.array(picture.convert("RGBA"))
    for top in range(0, pixels.shape[0], cell_height):
        for left in range(0, pixels.shape[1], cell_width):
            cell = pixels[top : top + cell_height, left : left + cell_width]
            drawn = cell[:, :, 3] > 0
            if not drawn.any():
                continue
            noise = np.random.default_rng([RANK_SEED, top // cell_height, left // cell_width]).random(drawn.shape)
            rows = np.where(drawn.any(axis=1))[0]
            heights = np.clip((np.arange(drawn.shape[0]) - rows[0]) / max(1, rows[-1] - rows[0]), 0, 1)
            rank = (1 - RANK_NOISE) * heights[:, None] + RANK_NOISE * noise if is_top_down else noise
            cell[:, :, 3] = np.where(drawn, 1 + np.round(np.clip(rank, 0, 1) * 254), 0)
    return Image.fromarray(pixels, "RGBA")


def write_textures(tile_size):
    """Writes the threshold map and the fallen leaves of the art set being drawn (see palette.art_set)
    into the folder of the data textures."""
    folder = palette.GENERATED / palette.DATA_TEXTURES
    folder.mkdir(parents=True, exist_ok=True)
    ground_noise(tile_size).save(folder / palette.set_file("ground_noise.png"))
    leaf_litter(tile_size).save(folder / palette.set_file("leaf_litter.png"))
