class_name CoopCase
extends LivestockCase
## What the tests of the chicken coop share: a coop in the pen and helpers for its hens and eggs.

const NIGHT := 23 * 60
const MORNING := 8 * 60
## The top left tile of the coop in the pen, relative to the pen's middle: its door is on the tile
## below the one below its top left tile.
const COOP_AT := Vector2i(0, -1)

var _coop: Building
## A reachability that lets every tile be reached.
var _anywhere := func(_front: Vector2i) -> bool: return true


func before_each() -> void:
	super()
	_coop = _world.place_building(BuildingTypes.CHICKEN_COOP, _middle + COOP_AT)
	_livestock.yard = _yard_with("egg_chance", 1.0)
	_state.cheats.are_needs_off = true


## The yard rules with one number of the coop changed.
func _yard_with(key: String, value: Variant) -> YardRules:
	var values := DataFile.read_sections(YardRules.DEFAULT_PATH)
	values["coop"][key] = value
	return YardRules.new(values)


func _hens(count: int) -> Array[FarmAnimal]:
	var hens: Array[FarmAnimal] = []
	for index in count:
		var hen := FarmAnimal.new(
			LivestockRules.CHICKEN,
			&"brown",
			_pen_middle() + Vector2(float(index % 3) - 1.0, 2.0 + index / 3)
		)
		_livestock.add(hen)
		_livestock.stand_still(hen)
		hens.append(hen)
	return hens


func _housed(hens: Array[FarmAnimal]) -> Array[FarmAnimal]:
	return hens.filter(func(hen: FarmAnimal) -> bool: return hen.is_housed)


func _eggs() -> int:
	var eggs := 0
	for nest in Coop.nests(_coop):
		eggs += Coop.eggs_in(nest)
	return eggs


## Walks the player into the coop to the middle of its floor, and holds an empty hand.
func _go_in() -> void:
	_state.player.position = Vector2(_coop.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	_state.player.position = Vector2(2.5, 3.5)
	HotbarHold.hold(_state.player.inventory, ItemTypes.NONE)


## The game saved and loaded, with the chunks that are loaded.
func _reloaded() -> GameState:
	var restored := GameState.from_dict(JSON.parse_string(JSON.stringify(_state.to_dict())))
	for coords in _world.loaded_chunk_coords():
		restored.world.add_chunk(WorldGenerator.new(SEED).generate_chunk(coords))
	return restored


func _eggs_of(coop: Building) -> int:
	var eggs := 0
	for nest in Coop.nests(coop):
		eggs += Coop.eggs_in(nest)
	return eggs


## Lets `seconds` of play pass in `state` at a time of day, as `_run` does for the test's own.
func _run_in(state: GameState, seconds: float, minute: int) -> void:
	for _step in int(seconds / STEP_SECONDS):
		state.clock.day = DAY
		state.clock.minute_of_day = minute
		state.livestock.update(STEP_SECONDS, state.world, state.player.position, state.clock)
