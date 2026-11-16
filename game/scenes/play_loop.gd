class_name PlayLoop
extends RefCounted
## What moves each frame of play, and when: real time turned into game minutes and the state's
## per-frame work (see GameState `frame_work`) at the start of the frame, the villagers, animals and
## chunk streaming after the player has walked. The world, its animals too, stands still while the
## player is in a house and while the sleep is made up for in steps; but the villagers on a trip go
## on over the masks, so they are where one expects them when the player comes out. Main calls it
## from `_process`, between its own steps.

var _state: GameState
var _clock_ticker: GameClockTicker
var _blackout: BlackoutFlow
var _residency: ChunkResidency
var _view: WorldView
var _player_view: PlayerView
var _ground_item_view: GroundItemView
var _npc_views: NpcViews


func _init(
	state: GameState,
	clock_ticker: GameClockTicker,
	blackout: BlackoutFlow,
	residency: ChunkResidency,
	view: WorldView,
	player_view: PlayerView,
	ground_item_view: GroundItemView,
	npc_views: NpcViews
) -> void:
	_state = state
	_clock_ticker = clock_ticker
	_blackout = blackout
	_residency = residency
	_view = view
	_player_view = player_view
	_ground_item_view = ground_item_view
	_npc_views = npc_views


## F2: a game day in 16 real seconds, and back.
func toggle_fast_forward() -> void:
	_clock_ticker.is_fast_forward = not _clock_ticker.is_fast_forward


## The start of the frame: time passes and the state does the work of the frame.
func begin_frame(delta: float) -> void:
	_clock_ticker.tick(delta)
	_state.frame_work(delta)


## The rest of the frame: what lives in the world moves, as far as the player's place and the sleep
## allow.
func move_world(delta: float) -> void:
	if _blackout.is_making_up_time:
		return
	if _state.is_inside():
		_state.npcs.update_unseen(delta, _state.world, _state.clock)
		_state.npcs.update_inside(delta, _state.current_map as Interior, _state.clock)
		return
	_state.livestock.update(delta, _state.world, _state.player.position, _state.clock)
	_state.npcs.update(delta, _state.world, _state.player.position, _state.clock)
	_view.player_feet = _player_view.position
	_view.player_size = (
		Occlusion.RIDER_SIZE if _state.player.horse != null else Occlusion.PLAYER_SIZE
	)
	_residency.set_focus(_state.player.tile())
	_residency.update(func() -> bool: return not _view.is_drawing())
	_ground_item_view.set_focus(_state.player.tile())
	_npc_views.set_focus(_state.player.tile())


## The chunks of the world stay as they are while the player is in a house or the sleep is made up
## for. Called when the map shown changes.
func update_streaming_hold() -> void:
	_residency.is_held = _state.is_inside() or _blackout.is_making_up_time
