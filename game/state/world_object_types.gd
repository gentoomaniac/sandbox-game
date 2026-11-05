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
## - growth_stages, days_per_stage: the object is a crop. Its `days_grown` state sets its
##   stage; the last stage is ripe. Its atlas variants are the stages.
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

## The largest footprint any type has, in tiles: what World looks back over to find the
## object that covers a tile.
const MAX_FOOTPRINT := Vector2i(2, 2)

const TYPES := {
	OAK:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 0,
		"sprite_height": 64,
		"variants": 3,
	},
	STONE:
	{
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
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 4,
		"sprite_height": 66,
		"variants": 3,
	},
	PINE:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 5,
		"sprite_height": 60,
		"variants": 3,
	},
	DEAD_TREE:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 6,
		"sprite_height": 48,
		"variants": 3,
	},
	BERRY_BUSH:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 0,
		"atlas_row": 7,
		"variants": 3,
	},
	SHRUB:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 8,
		"variants": 3,
	},
	SAPLING:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 9,
		"variants": 3,
	},
	FERN_BUSH:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 10,
		"variants": 3,
	},
	TURNIP:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 11,
		"variants": 4,
		"growth_stages": 4,
		"days_per_stage": 1,
	},
	BOULDER:
	{
		"footprint": Vector2i(2, 1),
		"blocks_walking": true,
		"harvest_level": 2,
		"atlas_row": 12,
		"variants": 2,
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
