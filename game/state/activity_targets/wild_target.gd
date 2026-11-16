class_name WildTarget
extends ActivityTarget
## A meadow tile that can be stood on, at a distance from the villager's home between
## NEAREST_TILES and the `search_tiles` of the rules, picked from the day and their name: the
## same all day, and another tomorrow. Only tiles of loaded chunks are known, so a villager far from
## the player has none.

## A spot is looked for this many times before there is none.
const TRIES := 24
const NEAREST_TILES := 8.0


func kind() -> String:
	return "wild"


func is_searched() -> bool:
	return true


func is_found_when_on() -> bool:
	return true


func spot_of(npc: Npc, day: int, places: ActivityPlaces) -> Vector2:
	var home := places.home_point(npc)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([npc.name, day, kind()])
	for _try in TRIES:
		var distance := rng.randf_range(NEAREST_TILES, places.rules.search_tiles(kind()))
		var tile := Vector2i((home + Vector2.from_angle(rng.randf() * TAU) * distance).floor())
		if _is_meadow(tile, places.world):
			return Vector2(tile) + Vector2(0.5, 0.5)
	return ActivityPlaces.NOWHERE


func _is_meadow(tile: Vector2i, world: World) -> bool:
	var ground := world.tile_at(tile)
	return (
		ground != null
		and ground.terrain == Tile.Terrain.GRASS
		and world.object_at(tile) == null
		and world.is_walkable(tile)
	)
