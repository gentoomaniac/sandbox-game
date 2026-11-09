"""The atlases of sheets: the object and decoration atlases that Godot reads are packed by
pack.py (`make assets`) out of one small sheet per entity, which the generators write here and
artists can redraw one at a time.

An entity is an object type (`oak`, `chest`) or a ground layer's decorations (`grass`). Its sheet,
`<folder>/<entity>.png`, has a row per look (the seasons, see seasons.LOOKS) and a cell per
variant in a column, cells of the atlas's cell size. `<folder>/atlas.txt` lists the entities in
the order of the atlas's rows, each with the number of cells in a row of its sheet:

    cell 96 160
    looks spring summer autumn ...
    oak 3
    stone 2
"""

from palette import GENERATED, save

MANIFEST = "atlas.txt"


def save_sheets(folder, entities, looks, cells_by_look, cell_width, cell_height):
    """Writes the sheets of `entities` (their names, in the atlas's row order) into `folder`
    under art/generated/. `cells_by_look[look][i]` is the list of cells of entity i in that look."""
    counts = [len(cells) for cells in cells_by_look[looks[0]]]
    lines = [f"cell {cell_width} {cell_height}", f"looks {' '.join(looks)}"]
    for index, (entity, count) in enumerate(zip(entities, counts)):
        assert all(len(cells_by_look[look][index]) == count for look in looks), f"{entity}: looks differ in their variants"
        lines.append(f"{entity} {count}")
        if count:
            save([cells_by_look[look][index] for look in looks], f"{folder}/{entity}.png", cell_width, cell_height)
    (GENERATED / folder).mkdir(parents=True, exist_ok=True)
    (GENERATED / folder / MANIFEST).write_text("\n".join(lines) + "\n")


def read_manifest(path):
    """The cell size, the looks and the (entity, cells) rows of the atlas manifest at `path`."""
    (_, width, height), (_, *looks), *rows = [line.split() for line in path.read_text().splitlines()]
    return (int(width), int(height)), looks, [(name, int(count)) for name, count in rows]
