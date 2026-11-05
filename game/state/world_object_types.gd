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
## footprint, its bottom on the footprint's bottom edge. Optional:
## - sleep_minutes: the object is a bed, and sleeping in it takes this long;
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
##   Their pictures are the rows after the stump's in the atlas, long then short per tree;
## - regrow_days: picking it by hand does not remove it: it looks picked and gives its drops
##   again after this many days (berry bush); the atlas row then has the picked looks after
##   the normal ones, `variants` of each;
## - matures_after_days: with the state `tree` set (a sapling that grows) it is replaced after
##   this many days by `matures_into`, or by the tree named in `tree`;
## - rots_after_days: it is gone after this many days (a stump), but for the chance
##   `rots_into_sapling_chance` that a sapling of the tree in its state `tree` stands in its place;
## - seasonal: it follows a yearly curve of the same name (see Vegetation): DORMANCY, it is
##   gone from the world while the density is below its threshold (a fern), or FRUIT, it
##   looks picked and can't be picked while it is (a berry bush). Woody plants have none;
## - sprite_height: its picture's height in pixels, if it is tall enough to hide the player
##   behind it (trees); only those become see-through (see Occlusion);
## - light: it shines: `color`, `energy` (of the brightest point) and `radius_tiles`.

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
const FERN_BUSH := &"fern_bush"
const TURNIP := &"turnip"
const BOULDER := &"boulder"
const SMALL_BED := &"small_bed"
const TABLE := &"table"
const STOOL := &"stool"
const CHEST := &"chest"
const HEARTH := &"hearth"
const WINDOW := &"window"
const STUMP := &"stump"

## Values of a type's `seasonal` entry.
const DORMANCY := &"dormancy"
const FRUIT := &"fruit"

## The largest footprint any type has, in tiles: what World looks back over to find the
## object that covers a tile.
const MAX_FOOTPRINT := Vector2i(2, 2)

## The first atlas row of the trunks: the row after the last of the other types.
const _FIRST_TRUNK_ROW := 13

const _OTHER_TYPES := {
	OAK:
	{
		"hp": 5,
		"tool": &"axe",
		"seed": &"acorn",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 4},
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
		"sleep_minutes": 8 * GameClock.MINUTES_PER_HOUR,
	},
	SPRUCE:
	{
		"hp": 4,
		"tool": &"axe",
		"seed": &"spruce_cone",
		"seed_chance": 0.25,
		"trunk": {"logs": 3, "hp": 3},
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
		"trunk": {"logs": 4, "hp": 5},
		"leaves": STUMP,
		"regrows": true,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 5,
		"sprite_height": 60,
		"variants": 3,
	},
	DEAD_TREE:
	{
		"hp": 3,
		"tool": &"axe",
		"trunk": {"logs": 2, "hp": 2},
		"leaves": STUMP,
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 6,
		"sprite_height": 48,
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
	SMALL_BED:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/bed.png",
		"sleep_minutes": 6 * GameClock.MINUTES_PER_HOUR,
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
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
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
	# Wall decoration: it stands on the wall tiles of the back wall face.
	WINDOW:
	{
		"footprint": Vector2i(1, 2),
		"blocks_walking": true,
		"harvest_level": 0,
		"interior_sprite": "res://assets/interior/window.png",
	},
}

## Every type: the fixed ones above and the crops of data/crops.cfg.
# The name is that of a constant, but crop types are only known once the file is read.
static var TYPES := _with_trunks(_with_crops(_OTHER_TYPES))  # gdlint: ignore=class-variable-name


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


## Adds the trunk types of the trees that have a `trunk`, as the data of the tree says.
static func _with_trunks(other_types: Dictionary) -> Dictionary:
	var types := other_types.duplicate()
	var row := _FIRST_TRUNK_ROW
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
				"atlas_row": row,
				"variants": 2,
			}
			row += 1
	return types
