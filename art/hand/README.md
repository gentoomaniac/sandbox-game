# Hand-drawn art

Drop a picture or a sound here to use it instead of the generated one; `make assets` finds it.
No tool ever writes in this folder.

A file has the path and name of the generated file in `art/generated/`, with a postfix for the
art set it replaces:

- `_32x32` for the new art, drawn at 32 px per tile: `objects/oak_32x32.png` replaces
  `art/generated/objects/oak.png`.
- `_16x16` for the classic art, drawn at 16 px per tile: `objects/oak_16x16.png` replaces
  `art/generated/classic/objects/oak.png`.
- Sounds have no postfix: `sounds/axe_chop_1.wav` replaces `art/generated/sounds/axe_chop_1.wav`.

A picture has the generated one's size exactly. In a sheet (the rows and columns of an object's
looks and variants, the frames of an animal), a cell you leave empty (fully transparent) stays the
generated one, so you can redraw one entity, or one cell of it, at a time. Colours outside the
palette are warned about, not refused. `make assets` lists the hand files it used and fails on a
hand file that replaces nothing (a typo in the path or the postfix).

How to do it step by step: [tools/README.md](../../tools/README.md), "Replacing one entity's art
by hand".
