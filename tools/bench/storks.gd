extends SceneTree
## Counts how often wild storks (the hunting `stork` and the `roof_stork`, not the pairs of the
## nests) come into the view and how many are there at once, over a simulated game day in spring
## and in summer, at a village and at wet meadows of a new game's world. The player stands still,
## or walks a circle (the storks flee, the view changes), or the time is skipped every 40 seconds,
## about an hour of game time (see WildlifeView `settle`). Prints one line for each run. Needs no
## save and writes nothing.
## godot --headless --path . -s tools/bench/storks.gd [-- --seed=<n>]

const FRAME := 0.1
const CHUNK_RADIUS := 4
const DAYS := {"spring": 15, "summer": 45}
const FIRST_HOUR := 6
const LAST_HOUR := 22
const WALK_RADIUS_TILES := 12.0
const WALK_TILES_PER_SECOND := 2.5
const SKIP_SECONDS := 40.0
const GAME_MINUTES_PER_SECOND := 1.5
const TILE := TerrainTileset.TILE_SIZE
const SEARCH_RADIUS_TILES := 70
const WET_RADIUS := 4
const FAR_APART_TILES := 40.0
const HOUSE_SPACING := 3
const HOUSES := 6
const VILLAGE_REACH := 12

var _world_seed := 1
var _state: GameState
var _wildlife: WildlifeView
var _camera: CameraController


func _process(_delta: float) -> bool:
	if _state != null:
		return false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			_world_seed = int(argument.trim_prefix("--seed="))
	_state = GameState.new_game(_world_seed)
	var generator := WorldGenerator.new(_world_seed)
	for y in range(-CHUNK_RADIUS, CHUNK_RADIUS):
		for x in range(-CHUNK_RADIUS, CHUNK_RADIUS):
			if not _state.world.is_chunk_loaded(Vector2i(x, y)):
				_state.world.add_chunk(generator.generate_chunk(Vector2i(x, y)))
	var sites := _find_sites()
	print("seed ", _world_seed, " sites ", sites)
	for site_name in sites:
		for season in DAYS:
			for mode in ["standing", "walking", "skipping"]:
				_measure(site_name, sites[site_name], season, mode)
	quit()
	return true


## Two wet meadows far apart: the village is built on the second. A new world has no village of
## its own, so houses are placed round the tile, as a player builds.
func _find_sites() -> Dictionary[String, Vector2i]:
	var sites: Dictionary[String, Vector2i] = {}
	for radius in SEARCH_RADIUS_TILES:
		for angle in 16:
			var tile := Vector2i(Vector2.from_angle(TAU * angle / 16.0) * radius)
			if not _is_wet_meadow(tile):
				continue
			if sites.is_empty():
				sites["meadows"] = tile
			elif Vector2(tile).distance_to(Vector2(sites["meadows"])) > FAR_APART_TILES:
				sites["village"] = tile
				_build_village(tile)
				return sites
	return sites


func _build_village(centre: Vector2i) -> void:
	var placed := 0
	for y in range(-VILLAGE_REACH, VILLAGE_REACH + 1, HOUSE_SPACING):
		for x in range(-VILLAGE_REACH, VILLAGE_REACH + 1, HOUSE_SPACING):
			if (
				placed < HOUSES
				and _state.world.place_building(BuildingTypes.KATE, centre + Vector2i(x, y)) != null
			):
				placed += 1
	print("village of ", placed, " houses at ", centre)


func _is_wet_meadow(tile: Vector2i) -> bool:
	var ground := _state.world.tile_at(tile)
	return (
		ground != null
		and ground.terrain in [Tile.Terrain.GRASS, Tile.Terrain.FLOODPLAIN, Tile.Terrain.WETLAND]
		and WildlifeRules.has_water_near(_state.world, tile, WET_RADIUS)
	)


func _measure(site_name: String, site: Vector2i, season: String, mode: String) -> void:
	_new_view()
	var centre := (Vector2(site) + Vector2(0.5, 0.5)) * TILE
	_set_player(centre)
	_state.clock.day = DAYS[season]
	_state.clock.set_time(FIRST_HOUR, 0)
	_state.weather_override = &"clear"
	var arrivals: Dictionary[int, bool] = {}
	var roof_arrivals: Dictionary[int, bool] = {}
	var at_once_sum := 0
	var most_at_once := 0
	var samples := 0
	var minutes_owed := 0.0
	var seconds := 0.0
	var next_skip := SKIP_SECONDS
	while _state.clock.minute_of_day < LAST_HOUR * 60:
		seconds += FRAME
		minutes_owed += GAME_MINUTES_PER_SECOND * FRAME
		if minutes_owed >= 1.0:
			_state.clock.advance(int(minutes_owed))
			minutes_owed -= int(minutes_owed)
		if mode == "walking":
			var angle := seconds * WALK_TILES_PER_SECOND / WALK_RADIUS_TILES
			_set_player(centre + Vector2.from_angle(angle) * WALK_RADIUS_TILES * TILE)
		if mode == "skipping" and seconds >= next_skip:
			next_skip += SKIP_SECONDS
			_wildlife.settle()
		_wildlife._process(FRAME)
		var at_once := 0
		for animal in _wildlife._animals:
			animal._process(FRAME)
			if animal.kind not in [WildlifeRules.STORK, WildlifeRules.ROOF_STORK]:
				continue
			if _wildlife._is_nest_parent(animal) or animal.is_done:
				continue
			at_once += 1
			arrivals[animal.get_instance_id()] = true
			if animal.kind == WildlifeRules.ROOF_STORK:
				roof_arrivals[animal.get_instance_id()] = true
		at_once_sum += at_once
		most_at_once = maxi(most_at_once, at_once)
		samples += 1
	print(
		(
			"%-8s %-7s %-8s arrivals %3d (%d on roofs) = %.2f per game hour, most at once %d, mean %.2f"
			% [
				site_name,
				season,
				mode,
				arrivals.size(),
				roof_arrivals.size(),
				float(arrivals.size()) / (LAST_HOUR - FIRST_HOUR),
				most_at_once,
				float(at_once_sum) / samples
			]
		)
	)


func _new_view() -> void:
	if _wildlife != null:
		_wildlife.world_view.free()
		_camera.free()
		_wildlife.free()
	_wildlife = WildlifeView.new()
	_wildlife.rng.seed = 1
	_wildlife.rules = WildlifeRules.for_session(_state.sun)
	_wildlife.nests = StorkNests.new(
		StorkNestRules.default_rules(), _state.sun, _state.world.world_seed
	)
	_wildlife._state = _state
	_wildlife.world_view = WorldView.new()
	root.add_child(_wildlife.world_view)
	_wildlife.world_view.show_world(ChunkResidency.new(_state.world))
	_wildlife.world_view.set_process(false)
	_wildlife.world_view.add_child(_wildlife.ground)
	_camera = CameraController.new()
	_wildlife._camera = _camera
	root.add_child(_wildlife)
	_wildlife.set_process(false)


func _set_player(feet: Vector2) -> void:
	_camera.rig.position = feet
	_wildlife.world_view.player_feet = feet
