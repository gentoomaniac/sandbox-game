"""The pictures of the buildings (assets/buildings/<id>.png): the registry of the modules that draw
them.

Each module of a family of buildings has a `PICTURES` dict: how to draw each building (is_lit to
the picture and the pixels snow covers), by its id in data/buildings.cfg; a style's as
<building>_<style>. A new building adds its module's `PICTURES` to `pictures` and generate.py stays
as it is.
"""

import buildings
import church
import declaration
import hall_house
import huts
import yard


def pictures():
    """The `PICTURES` of every module by building id; an id two modules draw is refused."""
    return declaration.merge({"buildings.py": buildings.PICTURES, "church.py": church.PICTURES, "hall_house.py": hall_house.PICTURES, "huts.py": huts.PICTURES, "yard.py": yard.PICTURES})
