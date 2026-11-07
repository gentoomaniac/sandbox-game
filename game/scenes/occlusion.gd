class_name Occlusion
extends RefCounted
## Which tall things hide the player: those drawn after the player (sorted by y, like the
## y-sorted `entities` node does) whose sprite overlaps the player's sprite. All in world
## pixels. Things behind the player never occlude it.

## Objects are drawn centred on their footprint and bottom-aligned, and sorted by the middle
## of its bottom row; a sprite is at most 5 tiles high, so only these tiles around the
## player's feet can reach its sprite.
const NEARBY_COLUMNS := 2
const NEARBY_ROWS_BELOW := 5
## The size of the player's sprite: one tile wide, two high. On horseback, the horse's body and
## the rider sitting on it (see PlayerView `SEAT`).
const PLAYER_SIZE := Vector2(TerrainTileset.TILE_SIZE, PlayerView.FRAME_HEIGHT)
const RIDER_SIZE := Vector2(
	2 * TerrainTileset.TILE_SIZE, PlayerView.FRAME_HEIGHT - PlayerView.SEAT.y
)


## The player's sprite of `size`, standing on `feet`.
static func player_rect(feet: Vector2, size := PLAYER_SIZE) -> Rect2:
	return Rect2(feet - Vector2(size.x / 2.0, size.y), size)


## The picture of an object, or an empty rect if it is too low to hide the player.
static func object_rect(object: WorldObject) -> Rect2:
	var height: int = WorldObjectTypes.TYPES[object.type].get("sprite_height", 0)
	if height == 0:
		return Rect2()
	var tile_size := TerrainTileset.TILE_SIZE
	var footprint: Vector2i = WorldObjectTypes.TYPES[object.type]["footprint"]
	var bottom_centre := Vector2(
		(object.pos.x + footprint.x / 2.0) * tile_size, (object.pos.y + footprint.y) * tile_size
	)
	return Rect2(
		bottom_centre - Vector2(ObjectTileset.CELL_WIDTH / 2.0, height),
		Vector2(ObjectTileset.CELL_WIDTH, height)
	)


## The y an object is sorted by: the middle of its bottom footprint row.
static func object_sort_y(object: WorldObject) -> float:
	var footprint: Vector2i = WorldObjectTypes.TYPES[object.type]["footprint"]
	return (object.pos.y + footprint.y - 0.5) * TerrainTileset.TILE_SIZE


## The picture of a building: as wide as its footprint, its bottom on the footprint's
## bottom edge, the roof rising above.
static func building_rect(building: Building) -> Rect2:
	var building_type: Dictionary = BuildingTypes.TYPES[building.type]
	var texture_size: Vector2 = load(building_type["sprite"]).get_size()
	var bottom_left := Vector2(building.origin + Vector2i(0, building_type["footprint"].y))
	bottom_left *= TerrainTileset.TILE_SIZE
	return Rect2(bottom_left - Vector2(0, texture_size.y), texture_size)


## The y a building is sorted by: the middle of its bottom footprint row.
static func building_sort_y(building: Building) -> float:
	var footprint_height: int = BuildingTypes.TYPES[building.type]["footprint"].y
	return (building.origin.y + footprint_height - 0.5) * TerrainTileset.TILE_SIZE


## The objects near the player (of `size`) that hide it.
static func occluding_objects(
	feet: Vector2, world: World, size := PLAYER_SIZE
) -> Array[WorldObject]:
	var player_rect_now := player_rect(feet, size)
	var feet_tile := Vector2i((feet / TerrainTileset.TILE_SIZE).floor())
	var found: Array[WorldObject] = []
	for y in range(0, NEARBY_ROWS_BELOW + 1):
		for x in range(-NEARBY_COLUMNS, NEARBY_COLUMNS + 1):
			var object := world.object_at(feet_tile + Vector2i(x, y))
			if (
				object != null
				and not found.has(object)
				and object_sort_y(object) > feet.y
				and object_rect(object).intersects(player_rect_now)
			):
				found.append(object)
	return found


## The buildings that hide the player (of `size`).
static func occluding_buildings(
	feet: Vector2, buildings: Array[Building], size := PLAYER_SIZE
) -> Array[Building]:
	var player_rect_now := player_rect(feet, size)
	var found: Array[Building] = []
	for building in buildings:
		if (
			building_sort_y(building) > feet.y
			and building_rect(building).intersects(player_rect_now)
		):
			found.append(building)
	return found
