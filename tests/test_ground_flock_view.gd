extends WildlifeCase
## A ground flock that has taken off is seen from the front or from behind while it flies mostly
## down or up the screen and side on otherwise (see FlightView), where its sheet has those views:
## the geese's has (the waders', on the mud of a coast, have not).

## Where it flies off to in degrees from east (the screen's y points down, so 90 is down) and
## the view the geese show. The climb that every take-off adds tilts the direction up a little.
const GEESE_VIEWS := {
	0.0: FlightView.SIDE,
	90.0: FlightView.FRONT,
	180.0: FlightView.SIDE,
	270.0: FlightView.BACK,
	300.0: FlightView.BACK,
	60.0: FlightView.FRONT,
	120.0: FlightView.FRONT,
	240.0: FlightView.BACK,
}

## Day 1's low water: the mud the waders stand on is dry (see Tide).
const LOW_WATER := 373
const MUD_REACH := 12


func _flock_flying_towards(kind: StringName, degrees: float) -> GroundFlock:
	assert_eq(_wildlife.spawn_in_view(kind, 1), 1, kind)
	var flock: GroundFlock = _animals_of(GroundFlock).back()
	flock._take_off(Vector2.RIGHT.rotated(deg_to_rad(degrees)))
	_run(flock, 1.0)
	return flock


func test_geese_show_the_view_of_their_flight_direction() -> void:
	for degrees: float in GEESE_VIEWS:
		var flock := _flock_flying_towards(WildlifeRules.GEESE, degrees)
		var view: StringName = GEESE_VIEWS[degrees]
		var first := WildlifeSprites.frame_index(&"goose", view, 0)
		var frames := WildlifeSprites.frame_count(&"goose", view)
		for bird in flock._birds:
			assert_between(bird.sprite.frame, first, first + frames - 1, "%s degrees" % degrees)
			var is_flipped := view == FlightView.SIDE and degrees == 180.0
			assert_eq(bird.sprite.flip_h, is_flipped, "%s degrees" % degrees)


func test_waders_have_the_side_view_only() -> void:
	_lay_mud_around_the_view()
	for kind in [WildlifeRules.OYSTERCATCHER, WildlifeRules.DUNLIN]:
		var flock := _flock_flying_towards(kind, 90.0)
		assert_eq(flock._flight_view, FlightView.SIDE, kind)
		var first := WildlifeSprites.frame_index(flock._sheet_kind, FlightView.SIDE, 0)
		assert_between(flock._birds[0].sprite.frame, first, first + 2, kind)


## Mud around the middle of the view at low water, where the waders can be spawned.
func _lay_mud_around_the_view() -> void:
	var middle := Vector2i((VIEW_CENTRE / TerrainTileset.TILE_SIZE).floor())
	for y in range(-MUD_REACH, MUD_REACH + 1):
		for x in range(-MUD_REACH, MUD_REACH + 1):
			_state.world.set_terrain(middle + Vector2i(x, y), Tile.Terrain.MUD)
			_state.world.remove_object(middle + Vector2i(x, y))
	_state.clock.minute_of_day = LOW_WATER
	_wildlife.world_view.player_feet = TerrainTileset.tile_centre(middle)
