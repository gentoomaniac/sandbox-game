class_name WildlifeView
extends Node
## Ambient wildlife around the player: every second it asks the WildlifeRules how many animals
## of each kind there should be and adds or sends away animals to match, in the ring around
## the view (never on the player), and it takes away those that are done or far from the view.
## The animals are nodes in the world view's y-sorted `entities`. Nothing is saved: it is
## atmosphere, drawn with a random number generator.
##
## Debug: `spawn_in_view` puts animals in view (the `--wildlife` flag and the `spawn` console
## command); those are never sent away for the weather or the hour, and `is_player_ignored`
## makes every animal take no notice of the player (`--wildlife-calm`).

## An animal came into being (see `_add`).
signal animal_added(animal: Animal)

## Tries to find a place for one animal before giving up until the next second.
const SPAWN_TRIES := 10
const FLOCK_SIZE := Vector2i(3, 6)
## Where animals made by hand appear: this far from the player, in pixels.
const DEBUG_DISTANCE := Vector2(24.0, 70.0)
## A bee made by hand picks one of this many flowers nearest to the player.
const DEBUG_FLOWERS := 5

var rules: WildlifeRules
var world_view: WorldView
var rng := RandomNumberGenerator.new()
## The ground below the animals: shadows that fall on it (see Flock) are drawn here.
var ground := Node2D.new()
var is_player_ignored := false
## Off while the debug flag decides which animals there are.
var is_spawning_naturally := true
var _state: GameState
var _camera: CameraController
var _animals: Array[Animal] = []
var _seconds_to_tick := 0.0


func _init() -> void:
	rng.randomize()


## Shows wildlife in a world view, by the time, weather and view of the game.
func show_wildlife(state: GameState, view: WorldView, camera: CameraController) -> void:
	_state = state
	world_view = view
	_camera = camera
	rules = WildlifeRules.default_rules()
	rules.sun = state.sun
	ground.name = "Ground"
	view.add_child(ground)
	# Below the entities (objects, player, animals), above the terrain.
	view.move_child(ground, view.entities.get_index())


func _process(delta: float) -> void:
	_remove_gone_animals()
	if not is_spawning_naturally:
		return
	_seconds_to_tick -= delta
	if _seconds_to_tick <= 0.0:
		_seconds_to_tick += rules.general("tick_seconds")
		_match_counts()


## Takes every animal away (the player went indoors).
func clear() -> void:
	for animal in _animals:
		animal.queue_free()
	_animals.clear()


## Puts `count` animals of a kind in view, near the player. Returns how many it could place.
func spawn_in_view(kind: StringName, count: int) -> int:
	var spawned := 0
	for _i in count:
		if kind == WildlifeRules.FLOCK:
			_spawn_flock(true)
			spawned += 1
		elif _spawn_near_player(kind):
			spawned += 1
	return spawned


## The part of the world the camera shows, in world pixels.
func view_rect() -> Rect2:
	var size := ViewMath.visible_size(Vector2(get_window().size), _camera.rig.zoom)
	return Rect2(_camera.rig.position - size / 2.0, size)


## Whether a point of the ground can be stood on (not water, a tree or a wall).
func can_stand(point: Vector2) -> bool:
	return world_view.world.is_walkable(_tile_at(point))


## The tiles of trees within a number of tiles of a point, nearest first.
func trees_near(point: Vector2, tiles: int) -> Array[Vector2i]:
	var centre := _tile_at(point)
	var trees: Array[Vector2i] = []
	for y in range(centre.y - tiles, centre.y + tiles + 1):
		for x in range(centre.x - tiles, centre.x + tiles + 1):
			var object := world_view.world.object_at(Vector2i(x, y))
			if object != null and WildlifeRules.TREE_TYPES.has(object.type):
				trees.append(object.pos)
	trees.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a - centre).length_squared() < Vector2(b - centre).length_squared()
	)
	return trees


func has_flower(tile: Vector2i) -> bool:
	return world_view.decorations.has_flower(tile)


## The tiles of flowers in bloom within a number of tiles of a point.
func flowers_near(point: Vector2, tiles: int) -> Array[Vector2i]:
	var reach := tiles * WildlifeRules.TILE_SIZE
	return world_view.decorations.flower_tiles_within(Rect2(point, Vector2.ZERO).grow(reach))


## Adds or sends away animals until each kind has the number the rules ask for.
func _match_counts() -> void:
	var clock := _state.clock
	var weather := _state.current_weather()
	var chance_seconds := rules.general("tick_seconds")
	for kind in WildlifeRules.KINDS:
		var count := _count_of(kind)
		var target := rules.target_count(kind, clock.day, clock.minute_of_day, weather)
		if count > target:
			_send_away(kind, count - target)
			continue
		var chance := rules.spawn_chance(kind, clock.day, clock.minute_of_day, weather)
		if count < target and _animals.size() < rules.general("max_total"):
			if rng.randf() < chance * chance_seconds:
				_spawn_somewhere(kind)


func _count_of(kind: StringName) -> int:
	var count := 0
	for animal in _animals:
		if animal.kind == kind and not animal.is_done:
			count += 1
	return count


## Takes `excess` animals of a kind away: out of sight at once, in sight by running off.
func _send_away(kind: StringName, excess: int) -> void:
	var view := view_rect()
	for animal in _animals:
		if excess == 0:
			return
		if animal.kind != kind or animal.is_pinned or animal.is_done:
			continue
		excess -= 1
		if view.has_point(animal.position):
			animal.dismiss()
		else:
			animal.is_done = true


## Spawns an animal of a kind at a suitable place in the ring around the view, if it finds
## one.
func _spawn_somewhere(kind: StringName) -> void:
	if kind == WildlifeRules.FLOCK:
		_spawn_flock(false)
		return
	var view := view_rect()
	var player := world_view.player_feet
	if rules.needs_flowers(kind):
		var flowers := world_view.decorations.flower_tiles_within(
			view.grow(rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE)
		)
		flowers.shuffle()
		for tile in flowers.slice(0, SPAWN_TRIES):
			var point := TerrainTileset.tile_centre(tile)
			if rules.is_spawn_point(point, view, player) and _is_habitat(kind, point):
				_spawn(kind, point, false)
				return
		return
	for _try in SPAWN_TRIES:
		var point := rules.random_ring_point(view, rng)
		if rules.is_spawn_point(point, view, player) and _is_habitat(kind, point):
			_spawn(kind, point, false)
			return


## Whether a kind can live at a point: its terrain and trees, and ground to stand on if it
## walks.
func _is_habitat(kind: StringName, point: Vector2) -> bool:
	var tile := _tile_at(point)
	var terrain := world_view.world.tile_at(tile)
	if terrain == null or (not _is_flying(kind) and not can_stand(point)):
		return false
	var radius := rules.trees_radius(kind)
	var tree_count := WildlifeRules.count_trees(world_view.world, tile, radius) if radius > 0 else 0
	return rules.is_habitat(kind, terrain.terrain, tree_count)


## Places an animal of a kind within a short way of the player, by hand: at a flower for a
## bee, else on a spot where it can be. Returns whether there was one.
func _spawn_near_player(kind: StringName) -> bool:
	var player := world_view.player_feet
	if kind == WildlifeRules.BEE:
		var flowers := world_view.decorations.flower_tiles_within(view_rect())
		if flowers.is_empty():
			return false
		flowers.sort_custom(
			func(a: Vector2i, b: Vector2i) -> bool:
				var distance_a := TerrainTileset.tile_centre(a).distance_to(player)
				return distance_a < TerrainTileset.tile_centre(b).distance_to(player)
		)
		var flower: Vector2i = flowers[rng.randi() % mini(flowers.size(), DEBUG_FLOWERS)]
		_spawn(kind, TerrainTileset.tile_centre(flower), true)
		return true
	for _try in SPAWN_TRIES * 3:
		var distance := rng.randf_range(DEBUG_DISTANCE.x, DEBUG_DISTANCE.y)
		var point := player + Vector2.from_angle(rng.randf() * TAU) * distance
		if can_stand(point) or _is_flying(kind):
			_spawn(kind, point, true)
			return true
	return false


## A flock enters the view from its ring and crosses it. One made by hand starts inside the
## view, on its left, so that it can be seen at once.
func _spawn_flock(is_debug: bool) -> void:
	var view := view_rect()
	var start := rules.random_ring_point(view, rng)
	if is_debug:
		start = view.position + view.size * Vector2(0.2, rng.randf_range(0.25, 0.75))
	var goal := (
		view.get_center()
		+ Vector2(
			rng.randf_range(-0.3, 0.3) * view.size.x, rng.randf_range(-0.3, 0.3) * view.size.y
		)
	)
	var flock := Flock.new()
	flock.set_course(start, goal * 2.0 - start, rng.randi_range(FLOCK_SIZE.x, FLOCK_SIZE.y))
	_add(flock, is_debug)


func _spawn(kind: StringName, point: Vector2, is_pinned: bool) -> void:
	var animal: Animal
	match kind:
		WildlifeRules.BIRD:
			animal = Bird.new()
		WildlifeRules.RABBIT:
			animal = Rabbit.new()
		WildlifeRules.SQUIRREL:
			animal = Squirrel.new()
		WildlifeRules.DEER:
			animal = Deer.new()
		WildlifeRules.BEE:
			animal = Bee.new()
		WildlifeRules.BUTTERFLY:
			animal = Butterfly.new()
	animal.position = point
	_add(animal, is_pinned)


func _add(animal: Animal, is_pinned: bool) -> void:
	animal.wildlife = self
	animal.is_pinned = is_pinned
	_animals.append(animal)
	world_view.entities.add_child(animal)
	animal_added.emit(animal)


## Frees the animals that are done or far from the view.
func _remove_gone_animals() -> void:
	if _animals.is_empty():
		return
	var view := view_rect()
	var staying: Array[Animal] = []
	for animal in _animals:
		if animal.is_done or rules.is_beyond_view(animal.position, view):
			animal.queue_free()
		else:
			staying.append(animal)
	_animals = staying


func _is_flying(kind: StringName) -> bool:
	return kind in [WildlifeRules.BEE, WildlifeRules.BUTTERFLY]


func _tile_at(point: Vector2) -> Vector2i:
	return Vector2i((point / WildlifeRules.TILE_SIZE).floor())
