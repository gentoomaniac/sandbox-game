class_name WalkFlow
extends RefCounted
## What the player does by themselves each frame: passes out when out of energy, walks with the keys
## held, gets off a horse before a door, picks up what lies at their feet, lies in a bed and goes
## through a door. Nothing of it happens during a transition. Main calls it from `_process`, between
## its own steps.

var _state: GameState
var _blackout: BlackoutFlow
var _view: WorldView
var _build_mode: BuildMode
var _builder: Builder
var _player_view: PlayerView
var _harvest_hud: HarvestHud
var _interior_view: InteriorView
var _object_cover: ObjectCover
var _pass_door: Callable


## `pass_door` is what the door underfoot leads to, called in the middle of the fade.
func _init(
	state: GameState,
	blackout: BlackoutFlow,
	view: WorldView,
	build_mode: BuildMode,
	builder: Builder,
	player_view: PlayerView,
	harvest_hud: HarvestHud,
	interior_view: InteriorView,
	object_cover: ObjectCover,
	pass_door: Callable
) -> void:
	_state = state
	_blackout = blackout
	_view = view
	_build_mode = build_mode
	_builder = builder
	_player_view = player_view
	_harvest_hud = harvest_hud
	_interior_view = interior_view
	_object_cover = object_cover
	_pass_door = pass_door


## `is_screen_open` is whether a window or the console takes the input: the player stands still.
func update(delta: float, is_screen_open: bool) -> void:
	# Out of energy after a use (or in a game saved while passing out), or up too late. A game
	# that starts so shows the world first.
	var is_drawn := _view.is_settled or _state.is_inside()
	if (
		(_state.is_out_of_energy() or _state.is_up_too_late)
		and is_drawn
		and not _blackout.is_in_transition
	):
		_blackout.pass_out()
	if _blackout.is_in_transition:
		return
	var direction := Vector2.ZERO
	if not is_screen_open:
		var is_menu_up := _build_mode.is_active() and not _builder.is_taking_down()
		direction = BuildMode.walk_direction(is_menu_up)
	_state.player.is_sprint_held = Input.is_action_pressed("sprint")
	_player_view.walk_speed = PlayerTravel.walk_speed_factor(_state)
	_player_view.is_trotting = PlayerTravel.is_trotting(_state)
	PlayerTravel.walk(_state, direction, delta, _player_view.walk_speed)
	if (
		_state.player.horse != null
		and direction != Vector2.ZERO
		and PlayerRest.is_door_ahead(_state)
	):
		_harvest_hud.show_note(UseNotes.GET_OFF_FIRST)
	GroundPickup.collect(_state, delta)
	_interior_view.cover_bed(_state.player.bed_lying_in)
	_object_cover.cover(_state.player.bed_lying_in)
	if PlayerRest.door_underfoot(_state):
		_blackout.fade_through(_pass_door)
