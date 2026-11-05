"""Item icons for building: the hammer.

Placeholders for the art pass (see TASKS.md): each function returns one 16x16 picture as rows
of palette colour names, like the rest of the art code, and generate.py only calls `icons`.
"""

import items


def hammer():
    """A wooden shaft with a heavy stone head across its top."""
    picture = items.canvas()
    items.shaft(picture, (3, 14), (9, 6))
    items.rect(picture, 6, 2, 14, 6, "stone")
    items.rect(picture, 6, 2, 14, 2, "stone_light")
    items.rect(picture, 6, 2, 6, 6, "stone_light")
    items.rect(picture, 6, 6, 14, 6, "stone_dark")
    return items.outlined(picture)


def icons():
    """The 16x16 icons by item id."""
    return {"hammer": hammer()}
