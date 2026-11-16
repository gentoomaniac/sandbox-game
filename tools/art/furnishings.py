"""The furniture of the interiors: the registry of the modules that draw it.

Each module of a family of furniture has a `pieces()` that gives its pieces by name, as their
picture and their footprint in tiles. A new piece is named in `declaration.FURNITURE` (that order is
the order of the tile ids of the tileset) and drawn by the `pieces()` of its module, which
`furniture` lists; generate.py stays as it is.
"""

import beds
import declaration
import interior


def furniture():
    """Every piece by name, in the order of `declaration.FURNITURE`: its picture and its footprint
    in tiles. A name two modules draw is refused."""
    drawn = declaration.merge({"beds.py": beds.pieces(), "interior.py": interior.pieces()})
    return dict(declaration.in_declared_order(declaration.FURNITURE, drawn, "the furniture"))
