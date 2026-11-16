"""The sheets of the farm animals (assets/wildlife/<species>_<look>.png): the registry of the
species modules.

Each family of species has a module, livestock_<family>.py, whose `sheets()` yields its files; the
drawing they share (poses, legs, the way a frame is put together) is livestock.py. A new species
adds its module and a line to FAMILIES, and generate.py stays as it is.
"""

import livestock

FAMILIES = (livestock,)


def sheets():
    """Every sheet as (file name, cell size, rows of cells for palette.save)."""
    for family in FAMILIES:
        yield from family.sheets()
