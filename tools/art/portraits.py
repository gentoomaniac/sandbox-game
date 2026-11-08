"""Portraits for the chat (assets/character/portrait/<slot>_<variant>.png): head and shoulders,
facing the viewer, one 32x32 picture per layer.

A portrait is the top of the layer's frame facing the viewer, standing still (see
character.py): the figure's own face, hair and hat, and its clothes down to the chest, cut off
at the picture's bottom edge. The game lays a figure's portrait layers over each other in the
order of its sheets (see game/state/appearance.gd), so a villager's portrait wears what the
villager wears. Only the layers that show in a bust have one: the body, clothes, coat, hair and
head; the legs, feet, apron and the held tool do not.
"""

from character import POSES, draw_body, draw_hair, draw_hat, draw_shirt, draw_waistcoat, draw_jacket, outlined, pixels_of, worn
from villagers import draw_bodice, draw_cap, draw_shawl

PORTRAIT_SIZE = 32
# The drawings of the layers that show in a bust.
BUST = (draw_body, draw_shirt, draw_waistcoat, draw_bodice, draw_jacket, draw_shawl, draw_hair, draw_hat, draw_cap)


def portraits(layer_sheets):
    """The portraits of the layers in `layer_sheets` (name to the sheet's drawing and colours, as
    `character.layers`) that show in a bust, by name, outlined like the sheets."""
    idle = POSES["idle"]
    body_pixels = pixels_of(draw_body("down", idle))
    result = {}
    for name, (draw, colours) in layer_sheets.items():
        if draw in BUST:
            frame = outlined(worn(draw, "down", idle, colours), set() if draw is draw_body else body_pixels)
            result[name] = frame[:PORTRAIT_SIZE]
    return result
