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
## - sapling_chance: a felled tree also drops a sapling item with this chance;
## - leaves: what stands in its place once it is cut down;
## - regrows: a tree that its stump grows back into (see matures_after_days);
## - regrow_days: picking it by hand does not remove it: it looks picked and gives its drops
##   again after this many days (berry bush); the atlas row then has the picked looks after
##   the normal ones, `variants` of each;
## - matures_after_days: with the state `tree` set (a stump or sapling that regrows) it is
##   replaced after this many days by `matures_into`, or by the tree named in `tree`;
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

const _OTHER_TYPES := {
	OAK:
	{
		"hp": 5,
		"tool": &"axe",
		"drops": {&"logs": 4},
		"sapling_chance": 0.25,
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
		"drops": {&"logs": 4},
		"sapling_chance": 0.25,
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
		"drops": {&"logs": 5},
		"sapling_chance": 0.25,
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
		"drops": {&"logs": 2},
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
		"drops": {&"sapling": 1},
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
		"matures_after_days": 3,
		"matures_into": SAPLING,
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
static var TYPES := _with_crops(_OTHER_TYPES)  # gdlint: ignore=class-variable-name


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
