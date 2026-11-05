class_name WorldObjectTypes
extends RefCounted
## The kinds of world object, as data. Keyed by type name; each entry has:
## - footprint: tiles covered (1x1 for now);
## - blocks_walking: whether the tile can be walked on while the object is there;
## - harvest_level: the tool level needed to harvest it;
## - atlas_row, variants: where its looks are in assets/objects.png (see the art generator).
## Optional:
## - sleep_minutes: the object is a bed, and sleeping in it takes this long;
## - light: it shines: `color`, `energy` (of the brightest point) and `radius_tiles`.

const OAK := &"oak"
const STONE := &"stone"
const FIREPLACE := &"fireplace"
const SLEEPING_BAG := &"sleeping_bag"

const TYPES := {
	OAK:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": true,
		"harvest_level": 1,
		"atlas_row": 0,
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
		# Energy 3 lifts the core of the light above the glow threshold (1.0).
		"light": {"color": Color(1.0, 0.6, 0.3), "energy": 3.0, "radius_tiles": 7.0},
	},
	SLEEPING_BAG:
	{
		"footprint": Vector2i(1, 1),
		"blocks_walking": false,
		"harvest_level": 0,
		"atlas_row": 3,
		"variants": 1,
		"sleep_minutes": 8 * GameClock.MINUTES_PER_HOUR,
	},
}
