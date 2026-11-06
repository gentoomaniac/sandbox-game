# Maps: the interiors of the buildings

Each building has a room, drawn in [Tiled](https://www.mapeditor.org/) and read by the game at
runtime: there is no export step, the `.tmx` file is the source. Tiled is only needed to edit
these maps; `make setup` reports it as optional.

```
maps/interiors/
  interior.tsx   the tileset all rooms share (its image is assets/interior.png)
  shack.tmx      one map per building id: shack, kate, longhouse, barn
```

A building's section in [data/buildings.cfg](../data/buildings.cfg) names its map in
`interior_map`, and the file must be called `<building id>.tmx` (a test checks it).

## Editing a room

Open the `.tmx` in Tiled and paint with the tiles of `interior.tsx`. Tiles are 16 x 16.

- The maps have two layers, `ground` and `furniture`. The loader reads every layer in the same
  way, so the names are a convention for the human: floor, walls and the door on `ground`,
  objects on `furniture`. Empty cells stay empty.
- **Layers must be CSV** (Tiled: Map Properties, Tile Layer Format: CSV), and the map uses
  exactly one tileset, `interior.tsx`, as an external file. Anything else fails an `assert`
  in `InteriorLoader` when the room loads.
- What a tile means is a property of the tile in `interior.tsx`:
  - `terrain`: `FLOOR` or `WALL` (a `Tile.Terrain` name). Walls block walking.
  - `exit` (bool): the tile that leaves the building. Every map needs one. It is the
    doormat in the front wall; the player appears on the tile above it when they come in,
    so keep that one free.
  - `object_type`: a name from `WorldObjectTypes` (`small_bed`, `table`, `hearth`...). An
    object of that type stands there; the cell is the **top left tile** of its footprint.
    A 2 x 2 hearth takes the cell at its top left and leaves the other three empty.
- A room's walls come from the ground tiles: the back wall is two rows (`back_*` tiles), the
  sides and the front wall are thin rims. Copy the border of an existing map for a new one.
  Which picture a wall tile gets is decided in `InteriorView` from where it is.

Run `make test` after editing. `tests/test_interior_maps.gd` checks that each room has its
walls, its door in the front wall, and that every free floor tile is reachable from the entry
and a free tile stands beside each bed.

## Adding a kind of furniture

Furniture tiles are generated, so a new one starts in the art code
([tools/README.md](../tools/README.md)):

1. Draw it in `tools/art/generate.py` and add it to `FURNITURE` with its footprint. Add it at
   the **end**: the order is the tile ids of the tileset, and existing maps refer to them.
2. Add its type to `WorldObjectTypes` with `interior_sprite` (the picture it made in
   `assets/interior/`) and its footprint.
3. Run `make assets`, then add a `<tile>` with the property `object_type` to `interior.tsx`
   at the next id (in Tiled, or copy a neighbouring entry), and enlarge the tileset's
   `tilecount`, `columns` and image `width` by one tile (16 px).
4. Paint it into a map.
