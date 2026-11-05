class_name WorldObjectTypes
extends RefCounted
## The kinds of world object, as data. Keyed by type name; each entry has:
## - footprint: tiles covered (1x1 for now);
## - blocks_walking: whether the tile can be walked on while the object is there;
## - harvest_level: the tool level needed to harvest it;
## - atlas_row, variants: where its looks are in assets/objects.png (see the art generator).

const OAK := &"oak"
const STONE := &"stone"

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
}
