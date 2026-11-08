"""Version A, "today": the scene composed from the real assets at 16 px per tile (320x180).

The ground follows game/scenes/terrain_tileset.gd: a dual grid, layers stacked bottom to
top, each drawing the edge shape of the corners on that layer or above, variants from
PositionHash. Objects, crops, buildings, characters and animals come from their sheets.
"""

from pathlib import Path

from PIL import Image

from scene import CREATURES, GROUND, H, THINGS, W

REPO = Path("/home/marco/git-private/sandbox-game")
A = REPO / "assets"
T = 16

LAYER = {"w": 0, "g": 4, "l": 7, "d": 8, "t": 9, "p": 10, "s": 11}
BASE = [0, 1, 2, 3, 4, 4, 4, 4, 4, 9, 10, 11]
EDGE_VARIANTS, FULL = 3, 15
FULL_COLUMN = EDGE_VARIANTS * FULL


def position_hash(x, y, salt=0):
    m = 0xFFFFFFFF
    h = salt & m
    h = ((h ^ (x & m)) * 0x9E3779B1) & m
    h ^= h >> 15
    h = ((h ^ (y & m)) * 0x85EBCA6B) & m
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & m
    return h ^ (h >> 16)


def layer_at(x, y):
    x = min(max(x, 0), W - 1)
    y = min(max(y, 0), H - 1)
    return LAYER[GROUND[y][x]]


def full_variant_counts(atlas):
    counts = []
    for row in range(atlas.height // T):
        n = 0
        while (FULL_COLUMN + n + 1) * T <= atlas.width:
            cell = atlas.crop(((FULL_COLUMN + n) * T, row * T, (FULL_COLUMN + n + 1) * T, (row + 1) * T))
            if cell.getbbox() is None:
                break
            n += 1
        counts.append(n)
    return counts


def ground(image):
    atlas = Image.open(A / "terrain.png").convert("RGBA")
    counts = full_variant_counts(atlas)
    for cy in range(H + 1):
        for cx in range(W + 1):
            corners = [layer_at(cx - 1, cy - 1), layer_at(cx, cy - 1), layer_at(cx - 1, cy), layer_at(cx, cy)]
            drawn = set()
            for layer in corners:
                drawn |= {layer, BASE[layer]}
            roll = position_hash(cx, cy)
            for layer in sorted(drawn):
                mask = sum(bit for bit, c in zip((1, 2, 4, 8), corners) if c >= layer)
                if mask == 0:
                    continue
                if mask == FULL:
                    column = FULL_COLUMN + roll % counts[layer]
                else:
                    column = roll % EDGE_VARIANTS * FULL + mask
                cell = atlas.crop((column * T, layer * T, (column + 1) * T, (layer + 1) * T))
                image.alpha_composite(cell, (cx * T - T // 2, cy * T - T // 2))
    # Decorations: a few tufts and stones, as decoration_cell does outside clusters, a bit more
    # often so the 20x11 tiles show some.
    deco = Image.open(A / "decorations.png").convert("RGBA")
    for y in range(H):
        for x in range(W):
            layer = layer_at(x, y)
            row = deco.crop((0, layer * T, deco.width, (layer + 1) * T))
            count = sum(1 for c in range(deco.width // T) if row.crop((c * T, 0, c * T + T, T)).getbbox())
            roll = position_hash(x, y, 1)
            if count and roll % 1000 < 150:
                c = roll // 1000 % count
                image.alpha_composite(row.crop((c * T, 0, c * T + T, T)), (x * T, y * T))


def object_cell(row, variant):
    atlas = Image.open(A / "objects.png").convert("RGBA")
    return atlas.crop((variant * 48, row * 80, variant * 48 + 48, row * 80 + 80))


def character(layers, facing):
    row = {"down": 0, "up": 1, "left": 2, "right": 3}[facing]
    im = Image.new("RGBA", (16, 32))
    for layer in layers:
        sheet = Image.open(A / "character" / f"{layer}.png").convert("RGBA")
        im.alpha_composite(sheet.crop((0, row * 32, 16, row * 32 + 32)))
    return im


ANIMALS = {
    "horse": ("horse_bay", 44, 36),
    "cow": ("cow_black_pied", 32, 24),
    "chicken": ("chicken_brown", 12, 12),
    "cat": ("cat_tabby", 16, 12),
    "mouse": ("mouse", 12, 7),
    "frog": ("frog", 12, 8),
}
PLAYER = ["body_0", "legs_0", "feet_clogs", "clothes_0", "hair_0", "head_straw_hat"]
VILLAGER = ["body_fair", "legs_skirt_red", "feet_clogs", "clothes_bodice_blue", "apron_white",
            "hair_bun_blond", "head_coif"]


def sprites():
    """(bottom y, picture, x, y) of everything standing, to be drawn bottom-sorted."""
    out = []
    for kind, tx, ty, extra in THINGS:
        if kind == "kate":
            pic = Image.open(A / "buildings" / "kate.png").convert("RGBA")
            bottom = (ty + 1) * T
            out.append((bottom, pic, tx * T, bottom - pic.height))
        elif kind in ("willow", "reeds", "tall_grass"):
            row = {"willow": 31, "reeds": 24, "tall_grass": 13}[kind]
            pic = object_cell(row, extra or 0)
            out.append(((ty + 1) * T, pic, tx * T - 16, (ty + 1) * T - 80))
        elif kind in ("cabbage", "wheat"):
            sheet = Image.open(A / "crops" / f"{kind}.png").convert("RGBA")
            stage = 3
            pic = sheet.crop((stage * 16, 0, stage * 16 + 16, sheet.height))
            out.append(((ty + 1) * T - 1, pic, tx * T, (ty + 1) * T - sheet.height))
    for kind, fx, fy, facing in CREATURES:
        if kind in ("player", "villager"):
            pic = character(PLAYER if kind == "player" else VILLAGER, facing)
        else:
            name, w, h = ANIMALS[kind]
            pic = Image.open(A / "wildlife" / f"{name}.png").convert("RGBA").crop((0, 0, w, h))
            if facing == "left":
                pic = pic.transpose(Image.FLIP_LEFT_RIGHT)
        px, py = round(fx * T), round(fy * T)
        out.append((py, pic, px - pic.width // 2, py - pic.height))
    return out


def render():
    """The view, 320x180."""
    image = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 255))
    ground(image)
    for _, pic, x, y in sorted(sprites(), key=lambda s: s[0]):
        image.alpha_composite(pic, (x, y)) if x >= 0 and y >= 0 else paste_clipped(image, pic, x, y)
    return image.crop((0, 0, 320, 180))


def paste_clipped(image, pic, x, y):
    left, top = max(0, -x), max(0, -y)
    image.alpha_composite(pic.crop((left, top, pic.width, pic.height)), (x + left, y + top))


if __name__ == "__main__":
    render().save("a_native.png")
