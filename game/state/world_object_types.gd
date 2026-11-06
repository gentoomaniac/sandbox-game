class_name WorldObjectTypes
extends RefCounted
## The kinds of world object, as data. Keyed by type name; each entry has:
## - footprint: tiles covered, from the object's own tile to the right and down (at most
##   MAX_FOOTPRINT);
## - blocks_walking: whether the tile can be walked on while the object is there;
## - harvest_level: the tool level needed to harvest it: 0 by hand (bushes and saplings), 1 an
##   axe or pickaxe (oak, spruce, dead tree, stone), 2 a better one (pine, the hardest wood,
##   boulder);
## - atlas_row, variants: where its looks are in assets/objects.png (see the art generator).
## Furniture, which only stands inside buildings, has `interior_sprite` (its picture in
## assets/interior/) instead of atlas_row and variants. The picture is centred on the
## footprint, its bottom on the footprint's bottom edge. The chest stands in both places, so it
## has both, and the ghost of an object the player places uses the interior picture. Optional:
## - storage_slots: it holds items, this many slots (a chest, see WorldObject `storage`);
## - bed: the object is a bed (what sleeping in it fills is in data/energy.cfg, [sleep]). Beds do
##   not block walking: the player wakes lying in the middle of one;
## - growth_stages: the object is a crop (all of them come from data/crops.cfg, see CropRules,
##   which says what the other values of a crop type are). Its picture sheet is not in the
##   object atlas but its own (`sheet`), with a picture per growth stage and a dead one;
## - hp, tool, drops: it can be cut down or mined: it has `hp` hit points, each hit of a `tool`
##   (an item's tool kind, as a plain name: ItemTypes can't be used here, it depends on this
##   file) of at least its harvest level takes off the tool's power, and when none are left it
##   gives its `drops` (item id to count, plain names for the same reason). Without `hp`,
##   `drops` are picked by hand, which removes the object;
## - seed and seed_chance: a felled tree also drops this item with this chance (it plants a
##   sapling of the tree; the dead tree has no seed);
## - leaves: what stands in its place once it is cut down;
## - regrows: its stump and the saplings of its seed remember the tree in the state `tree`, and
##   so can leave a sapling of it (see rots_after_days);
## - trunk: what felling leaves beside the stump, as `logs` (dropped when it is cut up) and `hp`.
##   The trunk's own types come from it (see `_with_trunks`, `trunk_type`): a trunk on 2x1 tiles
##   and a short one on 1x1, for when there is no room; they need the tree's harvest level.
##   Their pictures are the atlas row `atlas_row` (the long one) and the row after it (short);
## - regrow_days: picking it by hand does not remove it: it looks picked and gives its drops
##   again after this many days (berry bush); the atlas row then has the picked looks after
##   the normal ones, `variants` of each;
## - clearable: it gives way to the hoe, planting and building, which remove it without a drop
##   (tall grass);
## - tool (without hp): the item tool kind that mows it (tall grass): a hand can't pick it. A mown
##   one looks picked and grows back like a picked bush, see regrow_days;
## - regrow_growth: the wild reeds (their needs from data/crops.cfg, [reeds], are merged into the
##   type): cutting one with the scythe is like picking a bush, but it stands again by the growth
##   the weather gives it (see ReedLife) and not after a number of days;
## - matures_after_days: with the state `tree` set (a sapling that grows) it is replaced after
##   this many days by `matures_into`, or by the tree named in `tree`;
## - rots_after_days: it is gone after this many days (a stump), but for the chance
##   `rots_into_sapling_chance` (none without it: the dead tree's stump) that a sapling of the
##   tree in its state `tree` stands in its place;
## - seasonal: it follows a yearly curve of the same name (see Vegetation): DORMANCY, it is
##   gone from the world while the density is below its threshold (a fern), or FRUIT, it
##   looks picked and can't be picked while it is (a berry bush). Woody plants have none;
## - sprite_height: its picture's height in pixels, if it is tall enough to hide the player
##   behind it (trees); only those become see-through (see Occlusion);
## - light: it shines: `color`, `energy` (of the brightest point) and `radius_tiles`;
## - connects: it is a line across the land (a Knick, a wall, a dyke), drawn tile by tile: it
##   joins the neighbours on its 4 sides whose `connects` is the same, and each of its variants
##   has a picture per connection mask (see World `connections`) in its atlas row.

const OAK := &"oak"
const STONE := &"stone"
const FIREPLACE := &"fireplace"
const SLEEPING_BAG := &"sleeping_bag"
const SPRUCE := &"spruce"
const PINE := &"pine"
const DEAD_TREE := &"dead_tree"
const BERRY_BUSH := &"berry_bush"
const SHRUB := &"shrub"
const SAPLING := &"sapling"
## Drawn as the art kind "fern" (tools/art/generate.py keeps the old name: it seeds the art).
const FERN_BUSH := &"fern_bush"
const TURNIP := &"turnip"
const BOULDER := &"boulder"
const SMALL_BED := &"small_bed"
const TABLE := &"table"
const STOOL := &"stool"
const CHEST := &"chest"
const HEARTH := &"hearth"
const WINDOW := &"window"
const SLEEPING_MAT := &"sleeping_mat"
const BOX_BED := &"box_bed"
const BENCH := &"bench"
const STALL_PARTITION := &"stall_partition"
const HAY_PILE := &"hay_pile"
const BARREL := &"barrel"
const SACKS := &"sacks"
const CRATE := &"crate"
const PLATE_RACK := &"plate_rack"
const WALL_BENCH := &"wall_bench"
const STUMP := &"stump"
const DEAD_STUMP := &"dead_stump"
const TALL_GRASS := &"tall_grass"
const REEDS := &"reeds"
const KNICK := &"knick"
const WATTLE_FENCE := &"wattle_fence"
const STONE_WALL := &"stone_wall"
const DYKE := &"dyke"
const WILLOW := &"willow"
const BEECH := &"beech"
const BIRCH := &"birch"
const ALDER := &"alder"

## Values of a type's `seasonal` entry.
const DORMANCY := &"dormancy"
const FRUIT := &"fruit"

## The largest footprint any type has, in tiles: what World looks back over to find the
## object that covers a tile.
const MAX_FOOTPRINT := Vector2i(2, 2)

## The atlas rows of the long trunks; the short one is the row after each. They follow the order
## in which tools/art/generate.py lays out the object atlas (assets/objects_rows.txt, checked by a
## test), so a new tree gets the next free rows there and here.
const _OAK_TRUNK_ROW := 14
const _SPRUCE_TRUNK_ROW := 16
const _PINE_TRUNK_ROW := 18
const _DEAD_TREE_TRUNK_ROW := 20
const _WILLOW_TRUNK_ROW := 22
## The atlas row of the reeds: after the last trunk.
const _REEDS_ROW := 24
## The atlas row of the dead tree's stump, after the reeds.
const _DEAD_STUMP_ROW := 25
## The atlas row of the chest, after the dead tree's stump.
const _CHEST_ROW := 26
const _KNICK_ROW := 27
const _WATTLE_FENCE_ROW := 28
const _STONE_WALL_ROW := 29
const _DYKE_ROW := 30
const _WILLOW_ROW := 31
const _BEECH_ROW := 32
const _BEECH_TRUNK_ROW := 33
const _BIRCH_ROW := 35
const _BIRCH_TRUNK_ROW := 36
const _ALDER_ROW := 38
const _ALDER_TRUNK_ROW := 39
## The pictures of each variant of a type that `connects`: one per connection mask.
const CONNECTION_LOOKS := 16

const _OTHER_TYPES := {
	OAK:
	{
		"hp": 5,
		"tool": &"axe",
		"seed": &"acorn",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 4, "atlas_row": _OAK_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 0,
		"sprite_height": 64,
		"variants": 3,
	},
	STONE:
	{
		"hp": 3,
		"tool": &"pickaxe",
		"drops": {&"stone": 2},
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 1,
		"variants": 2,
	},
	FIREPLACE:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": 2,
		"variants": 1,
		# Deep orange at a moderate energy: brighter or paler turns the grass lime and
		# bleaches the player.
		"light": {"color": Color(1.0, 0.5, 0.22), "energy": 1.4, "radius_tiles": 7.0},
	},
	SLEEPING_BAG:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 3,
		"variants": 1,
		"bed": true,
	},
	SPRUCE:
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"spruce_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 3, "atlas_row": _SPRUCE_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 4,
		"sprite_height": 66,
		"variants": 3,
	},
	PINE:
	{
		"hp": 7,
		"tool": &"axe",
		"seed": &"pine_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 4, "hp": 5, "atlas_row": _PINE_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 5,
		"sprite_height": 75,
		"variants": 3,
	},
	DEAD_TREE:
	{
		"hp": 3,
		"tool": &"axe",
		"trunk": {"logs": 2, "hp": 2, "atlas_row": _DEAD_TREE_TRUNK_ROW},
		"leaves": DEAD_STUMP,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 6,
		"sprite_height": 55,
		"variants": 3,
	},
	# The pollard willow of the ditches, cut back to a head that sprouts rods.
	WILLOW:
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"willow_cutting",
		"seed_chance": 0.25,
		"trunk": {"logs": 2, "hp": 3, "atlas_row": _WILLOW_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _WILLOW_ROW,
		"sprite_height": 54,
		"variants": 3,
	},
	# The beech of the woods: smooth grey bark, a dense dome of a crown.
	BEECH:
	{
		"hp": 5,
		"tool": &"axe",
		"seed": &"beechnut",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 4, "atlas_row": _BEECH_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _BEECH_ROW,
		"sprite_height": 63,
		"variants": 3,
	},
	# The birch of the Geest and the wet woods: white bark, a light, open crown, soft wood.
	BIRCH:
	{
		"hp": 3,
		"tool": &"axe",
		"seed": &"birch_catkin",
		"seed_chance": 0.25,
		"trunk": {"logs": 2, "hp": 2, "atlas_row": _BIRCH_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _BIRCH_ROW,
		"sprite_height": 67,
		"variants": 3,
	},
	# The black alder of wet ground: dark bark, a narrow cone of dark leaves, cones in winter.
	ALDER:
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"alder_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 2, "hp": 3, "atlas_row": _ALDER_TRUNK_ROW},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _ALDER_ROW,
		"sprite_height": 66,
		"variants": 3,
	},
	BERRY_BUSH:
	{
		"drops": {&"berries": 3},
		"regrow_days": 3,
		"seasonal": FRUIT,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": 7,
		"variants": 3,
	},
	SHRUB:
	{
		"drops": {&"fibre": 2},
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 8,
		"variants": 3,
	},
	SAPLING:
	{
		"drops": {&"acorn": 1},
		"matures_after_days": 4,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 9,
		"variants": 3,
	},
	FERN_BUSH:
	{
		"drops": {&"fibre": 2},
		"seasonal": DORMANCY,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 10,
		"variants": 3,
	},
	BOULDER:
	{
		"hp": 6,
		"tool": &"pickaxe",
		"drops": {&"stone": 5},
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 11,
		"variants": 2,
	},
	STUMP:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 12,
		"variants": 2,
		"hp": 2,
		"tool": &"axe",
		"drops": {&"logs": 1},
		"rots_after_days": 14,
		"rots_into_sapling_chance": 0.3,
	},
	DEAD_STUMP:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _DEAD_STUMP_ROW,
		"variants": 2,
		"hp": 2,
		"tool": &"axe",
		"drops": {&"logs": 1},
		"rots_after_days": 14,
	},
	TALL_GRASS:
	{
		"drops": {&"hay": 2},
		"tool": &"scythe",
		"clearable": true,
		"regrow_days": 4,
		"seasonal": DORMANCY,
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 13,
		"variants": 3,
	},
	REEDS:
	{
		"drops": {&"reeds": 2},
		"tool": &"scythe",
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": _REEDS_ROW,
		"variants": 3,
	},
	# A hedge of hazel and hawthorn on an earth bank, between fields. The axe cuts it down to
	# the ground for its wood.
	KNICK:
	{
		"hp": 4,
		"tool": &"axe",
		"drops": {&"logs": 1, &"fibre": 2},
		"connects": &"field_boundary",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _KNICK_ROW,
		"variants": 3,
	},
	# Hazel rods woven between stakes: a light fence, cut down with the axe for its fibre.
	WATTLE_FENCE:
	{
		"hp": 2,
		"tool": &"axe",
		"drops": {&"fibre": 2},
		"connects": &"field_boundary",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _WATTLE_FENCE_ROW,
		"variants": 1,
	},
	# Fieldstones stacked dry: the pickaxe takes it apart for its stone.
	STONE_WALL:
	{
		"hp": 5,
		"tool": &"pickaxe",
		"drops": {&"stone": 3},
		"connects": &"field_boundary",
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _STONE_WALL_ROW,
		"variants": 3,
	},
	# A turfed bank of clay along the water: walked on like the grass, but nothing is built on
	# it, tilled or cut out of it.
	DYKE:
	{
		"connects": &"dyke",
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": _DYKE_ROW,
		"variants": 1,
	},
	SMALL_BED:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": false,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/bed.png",
		"bed": true,
	},
	TABLE:
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/table.png",
	},
	STOOL:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/stool.png",
	},
	CHEST:
	{
		"hp": 3,
		"tool": &"axe",
		"drops": {&"chest": 1},
		"storage_slots": 15,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": _CHEST_ROW,
		"variants": 1,
		"interior_sprite": "res://assets/interior/chest.png",
	},
	HEARTH:
	{
		"footprint": Vector2i(2, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/hearth.png",
		"light": {"color": Color(1.0, 0.5, 0.22), "energy": 1.2, "radius_tiles": 5.0},
	},
	SLEEPING_MAT:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": false,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/sleeping_mat.png",
		"bed": true,
	},
	BOX_BED:
	{
		"footprint": Vector2i(2, 2),
		"blocks_walking": false,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/box_bed.png",
		"bed": true,
	},
	BENCH:
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/bench.png",
	},
	STALL_PARTITION:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/stall_partition.png",
	},
	HAY_PILE:
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/hay_pile.png",
	},
	BARREL:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/barrel.png",
	},
	SACKS:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/sacks.png",
	},
	CRATE:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/crate.png",
	},
	# A bench against the back wall: its backboard stands on the wall above its footprint.
	WALL_BENCH:
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/wall_bench.png",
	},
	# Wall pieces: they stand on the wall tiles of the back wall face.
	WINDOW:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/window.png",
	},
	PLATE_RACK:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/plate_rack.png",
	},
}

## Every type: the fixed ones above and the crops of data/crops.cfg.
# The name is that of a constant, but crop types are only known once the file is read.
static var TYPES := _build_types()  # gdlint: ignore=class-variable-name


## The type of the trunk a felled tree leaves: the long one on 2x1 tiles, or the short one on 1x1.
static func trunk_type(tree: StringName, is_short: bool) -> StringName:
	return StringName("%s_%s" % [tree, "short_trunk" if is_short else "trunk"])


static func _with_crops(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	var rules := CropRules.default_rules()
	for crop_id in rules.crop_ids():
		var crop_type := rules.crop(crop_id).duplicate()
		crop_type["seed"] = StringName(crop_type["seed"])
		crop_type["produce"] = StringName(crop_type["produce"])
		crop_type["footprint"] = Vector2i(1, 1)
		crop_type["blocks_walking"] = false
		crop_type["harvest_level"] = 0
		crop_type["growth_stages"] = CropRules.STAGES
		types[crop_id] = crop_type
	return types


static func _build_types() -> Dictionary:
	var types := _with_crops(_OTHER_TYPES)
	types[REEDS] = types[REEDS].merged(CropRules.default_rules().reeds())
	return _with_trunks(types)


## Adds the trunk types of the trees that have a `trunk`, as the data of the tree says.
static func _with_trunks(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	for tree: StringName in other_types:
		var tree_data: Dictionary = other_types[tree]
		if not tree_data.has("trunk"):
			continue
		for is_short in [false, true]:
			types[trunk_type(tree, is_short)] = {
				"hp": tree_data["trunk"]["hp"],
				"tool": tree_data["tool"],
				"drops": {&"logs": tree_data["trunk"]["logs"]},
				"footprint": Vector2i(1, 1) if is_short else Vector2i(2, 1),
				"blocks_walking": true,
				"harvest_level": tree_data["harvest_level"],
				"atlas_row": tree_data["trunk"]["atlas_row"] + int(is_short),
				"variants": 2,
			}
	return types
