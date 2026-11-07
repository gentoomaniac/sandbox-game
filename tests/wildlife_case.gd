class_name WildlifeCase
extends GutTest
## What the tests of the wildlife on screen share: a WildlifeView over a new game's world, with a
## camera on `VIEW_CENTRE` and nothing spawning of its own accord. Nothing runs by itself either:
## a test steps an animal's frames with `run`. The view's dice are seeded, so a test throws the
## same numbers every run.

const VIEW_CENTRE := Vector2(80.0, 160.0)
const STEP := 0.1
const SEED := 1

var _state: GameState
var _wildlife: WildlifeView
var _camera: CameraController


func before_each() -> void:
	_state = GameState.new_game(1)
	_wildlife = WildlifeView.new()
	_wildlife.rng.seed = SEED
	_wildlife.rules = WildlifeRules.default_rules()
	_wildlife.is_player_ignored = true
	_wildlife._state = _state
	_wildlife.world_view = WorldView.new()
	add_child_autofree(_wildlife.world_view)
	_wildlife.world_view.show_world(_state.world)
	_wildlife.world_view.set_process(false)
	# As show_wildlife does: the ground is a Node2D nobody frees unless the world view owns it.
	_wildlife.world_view.add_child(_wildlife.ground)
	_camera = CameraController.new()
	autofree(_camera)
	_camera.rig.position = VIEW_CENTRE
	_wildlife._camera = _camera
	add_child_autofree(_wildlife)
	_wildlife.set_process(false)


## The wild animals of the view that are of a class (Stork, GooseFlock, Flock).
func _animals_of(type: Variant) -> Array[Animal]:
	var found: Array[Animal] = []
	for animal in _wildlife._animals:
		if is_instance_of(animal, type):
			found.append(animal)
	return found


## Steps an animal through this many seconds of frames.
func _run(animal: Animal, seconds: float) -> void:
	for _i in roundi(seconds / STEP):
		animal._process(STEP)
