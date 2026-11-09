class_name WildlifeView
extends Node
## Ambient wildlife around the player: every second it asks the WildlifeRules how many animals
## of each kind there should be and adds or sends away animals to match, in the ring around
## the view (never on the player), and it takes away those that are done or far from the view.
## The animals are nodes in the world view's y-sorted `entities`. Nothing is saved: it is
## atmosphere, drawn with a random number generator.
##
## It also shows the farm animals of the game's Livestock, which are state and saved: one
## FarmAnimalView each while it is near the view (in the ring or within it), looked at every
## second like the wild ones.
##
## Storks that stand on roofs fly in to a house near the view (see `_send_stork_to_roof`); where
## on a roof they can stand is read from the top edge of the house's picture.
##
## Debug: `spawn_in_view` puts animals in view (the `--wildlife` flag and the `spawn` console
## command); those are never sent away for the weather or the hour, and `is_player_ignored`
## makes every animal take no notice of the player (`--wildlife-calm`).

## An animal came into view: a wild one (see `_add`) or a farm animal (`_show_farm_animal_if_near`).
signal animal_added(animal: Animal)

## Tries to find a place for one animal before giving up until the next second.
const SPAWN_TRIES := 10
## Where animals made by hand appear: this far from the player, in pixels.
const DEBUG_DISTANCE := Vector2(48.0, 140.0)
## A bee made by hand picks one of this many flowers nearest to the player.
const DEBUG_FLOWERS := 5
## The birds of the coast keep to it even when made by hand: none appear where it is not near.
const SEA_BIRDS: Array[StringName] = [
	WildlifeRules.OYSTERCATCHER, WildlifeRules.DUNLIN, WildlifeRules.GULL, WildlifeRules.TERN
]
## A flock crossing the view starts this far behind the ring, in pixels.
const FLOCK_ENTRY_DISTANCE := 240.0
## A stork flying to a roof comes from this far beside the view, in pixels.
const ARRIVAL_MARGIN := 96.0
## A stork on a roof stands this many pixels into the top of the roof, among the ridge sticks.
const ROOF_FOOTING := 4.0

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
var _farm_animals: Dictionary[FarmAnimal, FarmAnimalView] = {}
## For each picture of a house (a building type in a look), how far its top is above the bottom
## edge, for every column of pixels: the roofs storks stand on. Read the first time it is needed.
var _roof_heights: Dictionary[String, PackedInt32Array] = {}
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
	state.livestock.added.connect(_show_farm_animal_if_near)
	ground.name = "Ground"
	view.add_child(ground)
	# Below the entities (objects, player, animals), above the terrain.
	view.move_child(ground, view.entities.get_index())


func _process(delta: float) -> void:
	_remove_gone_animals()
	_seconds_to_tick -= delta
	if _seconds_to_tick <= 0.0:
		_seconds_to_tick += rules.general("tick_seconds")
		_follow_farm_animals()
		if is_spawning_naturally:
			_match_counts()


## Takes every animal away (the player went indoors).
func clear() -> void:
	for animal in _animals:
		animal.queue_free()
	_animals.clear()
	for animal_view in _farm_animals.values():
		animal_view.queue_free()
	_farm_animals.clear()


## Puts `count` animals of a kind in view, near the player. Returns how many it could place.
func spawn_in_view(kind: StringName, count: int) -> int:
	var spawned := 0
	for _i in count:
		if kind in Flock.BIRDS:
			_spawn_flock(kind, true)
			spawned += 1
		elif kind == WildlifeRules.ROOF_STORK:
			if not _send_stork_to_roof(true):
				break
			spawned += 1
		elif _spawn_near_player(kind):
			spawned += 1
	return spawned


## Puts an animal of a kind at a point, to stay until it is far away (the `--hunt` flag).
func place(kind: StringName, point: Vector2) -> void:
	_spawn(kind, point, true)


## The nearest animal of a kind that is still about within `reach` pixels of a point, or null:
## how a hunter finds its prey (a stork its frogs, a cat its mice). It looks only at the few wild
## animals.
func nearest_animal(kind: StringName, point: Vector2, reach: float) -> Animal:
	var nearest: Animal = null
	var nearest_distance := reach
	for animal in _animals:
		if animal.kind == kind and not animal.is_done:
			var distance := animal.position.distance_to(point)
			if distance <= nearest_distance:
				nearest = animal
				nearest_distance = distance
	return nearest


## The farm animals of the game, which it shows (a cat asks it for mice to hunt).
func livestock() -> Livestock:
	return _state.livestock


## The part of the world the camera shows, in world pixels.
func view_rect() -> Rect2:
	var size := ViewMath.visible_size(Vector2(get_window().size), _camera.rig.zoom)
	return Rect2(_camera.rig.position - size / 2.0, size)


## Whether a point of the ground can be stood on: not water (see `is_water`), a tree or a wall.
func can_stand(point: Vector2) -> bool:
	return world_view.world.is_walkable(_tile_at(point)) and not is_water(point)


## Whether a point is on water: the sea and fresh water always, the tidal mud while the tide
## stands above `flooded_tide` (see data/wildlife.cfg).
func is_water(point: Vector2) -> bool:
	var ground := world_view.world.tile_at(_tile_at(point))
	if ground == null:
		return false
	if ground.terrain == Tile.Terrain.MUD:
		return tide() > rules.general("flooded_tide")
	return ground.terrain == Tile.Terrain.SEA or ground.terrain == Tile.Terrain.WATER


## How high the tide stands now, from 0 at low water to 1 at high water.
func tide() -> float:
	return Tide.level(_state.clock.total_minutes())


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


## Adds or sends away animals until each kind has the number the rules ask for. The flowers in
## bloom in and around the view are looked up once, for the kinds that live at them.
func _match_counts() -> void:
	var clock := _state.clock
	var weather := _state.current_weather()
	var chance_seconds := rules.general("tick_seconds")
	var flowers := world_view.decorations.flower_tiles_within(
		view_rect().grow(rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE)
	)
	for kind in WildlifeRules.KINDS:
		var count := _count_of(kind)
		var target := rules.target_count(
			kind, clock.day, clock.minute_of_day, weather, flowers.size()
		)
		if count > target:
			_send_away(kind, count - target)
			continue
		var chance := rules.spawn_chance(kind, clock.day, clock.minute_of_day, weather)
		if count < target and _animals.size() < rules.general("max_total"):
			if rng.randf() < chance * chance_seconds:
				_spawn_somewhere(kind, flowers)


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
## one: one that lives at flowers at one of `flowers`, the flowers in bloom around the view.
func _spawn_somewhere(kind: StringName, flowers: Array[Vector2i]) -> void:
	if kind in Flock.BIRDS:
		_spawn_flock(kind, false)
		return
	if kind == WildlifeRules.ROOF_STORK:
		_send_stork_to_roof(false)
		return
	var view := view_rect()
	var player := world_view.player_feet
	if rules.needs_flowers(kind):
		var points := rules.flower_spawn_points(flowers, view, player)
		points.shuffle()
		for point in points.slice(0, SPAWN_TRIES):
			if _is_habitat(kind, point):
				_spawn(kind, point, false)
				return
		return
	for _try in SPAWN_TRIES:
		var point := rules.random_ring_point(view, rng)
		if rules.is_spawn_point(point, view, player) and _is_habitat(kind, point):
			_spawn(kind, point, false)
			return


## Whether a kind can live at a point: its terrain, trees and water, and ground to stand on if
## it walks (or water, for a gull, which swims).
func _is_habitat(kind: StringName, point: Vector2) -> bool:
	var is_swimming := kind == WildlifeRules.GULL and is_water(point)
	if not _is_flying(kind) and not is_swimming and not can_stand(point):
		return false
	return rules.is_habitat_at(kind, world_view.world, _tile_at(point))


## Places an animal of a kind within a short way of the player, by hand: at a flower for a
## bee, where it lives for a bird of the coast, else on a spot where it can be. Returns whether
## there was one.
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
		var can_be_there := (
			_is_habitat(kind, point)
			if kind in SEA_BIRDS
			else (can_stand(point) or _is_flying(kind))
		)
		if can_be_there:
			_spawn(kind, point, true)
			return true
	return false


## A flock enters the view from beyond its ring and crosses it. One made by hand starts inside
## the view, on its left, so that it can be seen at once.
func _spawn_flock(kind: StringName, is_debug: bool) -> void:
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
	var end := goal * 2.0 - start
	if not is_debug:
		# High up, the birds would be seen at once from the ring: they start further back.
		start -= (goal - start).normalized() * FLOCK_ENTRY_DISTANCE
	var flock := Flock.new(kind)
	flock.set_course(start, end, Flock.bird_count(kind, rng))
	_add(flock, is_debug)


## Sends a stork to the roof of a house near the view that has none: it flies in from beside
## the view. One made by hand stands on the roof nearest to the player at once. Returns
## whether there was a roof for it.
func _send_stork_to_roof(is_debug: bool) -> bool:
	var near := view_rect().grow(rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE)
	var houses: Array[Building] = []
	for building in world_view.world.buildings():
		if near.has_point(_front_middle(building)) and not _has_stork_on(building):
			houses.append(building)
	if houses.is_empty():
		return false
	var house := houses[rng.randi() % houses.size()]
	if is_debug:
		var nearest := INF
		for building in houses:
			var distance := _front_middle(building).distance_to(world_view.player_feet)
			if distance < nearest:
				nearest = distance
				house = building
	var stork := Stork.new(WildlifeRules.ROOF_STORK)
	# On the ridge: the middle third of the picture, away from the hips.
	var footprint: Vector2i = BuildingTypes.TYPES[house.type]["footprint"]
	var width := footprint.x * WildlifeRules.TILE_SIZE
	var column := rng.randi_range(width / 3, width * 2 / 3)
	if is_debug:
		stork.stand_on(house, column, _in_front_of(house, column))
	else:
		# From beyond the left or right edge of the view, where it can't be seen high up as it is.
		var view := view_rect()
		var side := (
			view.position.x - ARRIVAL_MARGIN if rng.randf() < 0.5 else view.end.x + ARRIVAL_MARGIN
		)
		stork.position = Vector2(
			side, _in_front_of(house, 0).y + rng.randf_range(-0.3, 0.3) * view.size.y
		)
		stork.fly_to(house, column, _in_front_of(house, column))
	_add(stork, is_debug)
	return true


## How high above the point in front of a house (see `_in_front_of`) a stork stands on a column
## of the house's picture as it is shown now: its feet among the ridge sticks, ROOF_FOOTING pixels
## into the top of the roof. Under snow the roof is a little higher.
func roof_lift(building: Building, column: int) -> float:
	var heights := _roof_heights_of(world_view.building_picture(building))
	var feet := BuildingViews.footprint_bottom(building) - heights[column] + ROOF_FOOTING
	return _in_front_of(building, column).y - feet


## Whether a house still stands in the world.
func is_standing(building: Building) -> bool:
	return world_view.world.building_at(building.origin) == building


func _has_stork_on(building: Building) -> bool:
	for animal in _animals:
		if animal is Stork and animal.roof == building and not animal.is_done:
			return true
	return false


## The point of the ground just in front of a house, below a column of its picture: an animal
## there sorts right after the house.
func _in_front_of(building: Building, column: int) -> Vector2:
	return BuildingViews.sort_position(building) + Vector2(column, 1.0)


func _front_middle(building: Building) -> Vector2:
	var footprint: Vector2i = BuildingTypes.TYPES[building.type]["footprint"]
	return _in_front_of(building, footprint.x * WildlifeRules.TILE_SIZE / 2)


## For every column of pixels of a house's picture, how far its top is above the bottom edge.
func _roof_heights_of(picture: String) -> PackedInt32Array:
	if _roof_heights.has(picture):
		return _roof_heights[picture]
	var image: Image = load(picture).get_image()
	var heights := PackedInt32Array()
	heights.resize(image.get_width())
	for x in image.get_width():
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.5:
				heights[x] = image.get_height() - y
				break
	_roof_heights[picture] = heights
	return heights


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
		WildlifeRules.FIREFLY:
			animal = Firefly.new()
		WildlifeRules.STORK:
			animal = Stork.new(WildlifeRules.STORK)
		WildlifeRules.GEESE, WildlifeRules.OYSTERCATCHER, WildlifeRules.DUNLIN:
			animal = GroundFlock.new(kind)
		WildlifeRules.MOUSE:
			animal = Mouse.new()
		WildlifeRules.FROG:
			animal = Frog.new()
		WildlifeRules.GULL:
			animal = Gull.new()
		WildlifeRules.TERN:
			animal = Tern.new()
	animal.position = point
	_add(animal, is_pinned)


func _add(animal: Animal, is_pinned: bool) -> void:
	animal.wildlife = self
	animal.is_pinned = is_pinned
	_animals.append(animal)
	world_view.entities.add_child(animal)
	animal_added.emit(animal)


## Gives a farm animal its view if it has none and is in the ring around the view or within it.
func _show_farm_animal_if_near(animal: FarmAnimal) -> void:
	if _farm_animals.has(animal):
		return
	var near := view_rect().grow(rules.general("spawn_margin_tiles") * WildlifeRules.TILE_SIZE)
	if not near.has_point(animal.position * WildlifeRules.TILE_SIZE):
		return
	var animal_view := FarmAnimalView.new(animal)
	animal_view.wildlife = self
	_farm_animals[animal] = animal_view
	world_view.entities.add_child(animal_view)
	animal_added.emit(animal_view)


## Shows the farm animals that came near the view, and takes away those far from it.
func _follow_farm_animals() -> void:
	var view := view_rect()
	for animal: FarmAnimal in _farm_animals.keys():
		if rules.is_beyond_view(_farm_animals[animal].position, view):
			_farm_animals[animal].queue_free()
			_farm_animals.erase(animal)
	for animal in _state.livestock.all():
		_show_farm_animal_if_near(animal)


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
	return (
		kind
		in [WildlifeRules.BEE, WildlifeRules.BUTTERFLY, WildlifeRules.FIREFLY, WildlifeRules.TERN]
	)


func _tile_at(point: Vector2) -> Vector2i:
	return Vector2i((point / WildlifeRules.TILE_SIZE).floor())
