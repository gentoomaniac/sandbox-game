class_name MapSwitch
extends RefCounted
## Which map the views show: the world, or the interior of a house (which pauses the world's chunk
## streaming, leaving it as it is). Main creates it with the game, sets what it needs, and calls
## `show_current_map` when the player may have changed the map.

## What it needs from Main is set after `new()`: it takes more than the ten arguments that
## `_init` may.
var state: GameState
var audio: AudioService
var view: WorldView
var weather_view: WeatherView
var play_loop: PlayLoop
var interior_view: InteriorView
var interior_npc_views: InteriorNpcViews
var wildlife: WildlifeView
var player_view: PlayerView
var use_highlight: UseHighlight
var clock_views: ClockViews

var _shown_map: GameMap


func has_map_changed() -> bool:
	return state.current_map != _shown_map


## The player goes through the door underfoot.
func pass_door() -> void:
	state.pass_door()
	show_current_map()


func show_current_map() -> void:
	_shown_map = state.current_map
	var is_inside := state.is_inside()
	audio.set_inside(is_inside)
	view.visible = not is_inside
	weather_view.visible = not is_inside
	view.process_mode = Node.PROCESS_MODE_DISABLED if is_inside else Node.PROCESS_MODE_INHERIT
	play_loop.update_streaming_hold()
	interior_view.visible = is_inside
	if is_inside:
		wildlife.clear()
		interior_view.show_interior(state.current_map)
	interior_npc_views.show_room(state.current_map as Interior if is_inside else null)
	player_view.reparent(interior_view.entities if is_inside else view.entities, false)
	use_highlight.reparent(interior_view if is_inside else view, false)
	clock_views.show_clock()
