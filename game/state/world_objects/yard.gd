class_name WorldObjectYard
extends RefCounted
## What the player puts up in a yard as data, loaded into WorldObjectTypes `TYPES` (see there for
## the entries): the draw well, the troughs and the hay rack that hold a stock, the pig pen, the
## scarecrow and the grave.

const _GRAVE_ROW := 46
const _DRAW_WELL_ROW := 51
const _TROUGH_ROW := 52
const _HAY_RACK_ROW := 53
const _FEED_TROUGH_ROW := 54
const _PEN_FENCE_ROW := 55
const _PEN_GATE_ROW := 56
const _PIG_SHELTER_ROW := 57
const _PEN_GATE_OPEN_ROW := 58
const _SCARECROW_ROW := 59

const TYPES := {
	# The ring of the well blocks walking; the sweep above it is only drawn.
	&"draw_well":
	{
		"hp": 4,
		"tool": &"pickaxe",
		"drops": {&"draw_well": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _DRAW_WELL_ROW,
		"sprite_height": 82,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# The trough and the hay rack: what they hold is `stock` in their state.
	&"trough":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"trough": 1},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _TROUGH_ROW,
		"variants": 1,
		"stock_capacity": 100,
		"stock_kind": &"water",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"hay_rack":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"hay_rack": 1},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _HAY_RACK_ROW,
		"variants": 1,
		"stock_capacity": 100,
		"stock_kind": &"feed",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"feed_trough":
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"feed_trough": 1},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _FEED_TROUGH_ROW,
		"variants": 1,
		"stock_capacity": 100,
		"stock_kind": &"feed",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# Split oak rails between posts, about a pig's height: it keeps the animals in (or out).
	&"pen_fence":
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"pen_fence": 1},
		"connects": &"pen",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _PEN_FENCE_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# The gate of a pen: the player goes through it, shut or open (and shuts it behind them); the
	# animals only through an open one.
	&"pen_gate":
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"pen_gate": 1},
		"connects": &"pen",
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"stops_animals": true,
		"turns_into": &"pen_gate_open",
		"harvest_level": 1,
		"atlas_row": _PEN_GATE_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	&"pen_gate_open":
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"pen_gate": 1},
		"connects": &"pen",
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"turns_into": &"pen_gate",
		"harvest_level": 1,
		"atlas_row": _PEN_GATE_OPEN_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# A lean-to of boards under reed thatch, for the pigs to lie in out of the weather.
	&"pig_shelter":
	{
		"hp": 4,
		"tool": &"axe",
		"drops": {&"pig_shelter": 1},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _PIG_SHELTER_ROW,
		"variants": 1,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# Two stakes in a cross, dressed in straw. It stands outdoors, wherever the player wants it, and
	# has `placed_day` in its state from when it was put down.
	&"scarecrow":
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"scarecrow": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _SCARECROW_ROW,
		"variants": 1,
		"sway_frames": 3,
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
	# The grave marker the player places; its interior picture is the ghost (the oak cross).
	&"grave":
	{
		"hp": 2,
		"tool": &"pickaxe",
		"drops": {&"grave_marker": 1},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _GRAVE_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/grave.png",
		"placeable_in": WorldObjectTypes.OUTDOORS,
	},
}
