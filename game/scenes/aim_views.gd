class_name AimViews
extends RefCounted
## What the views show of what the player points at, each frame: the highlight of the use target,
## the action hint over the hotbar, the tooltip's world text, the name over a villager one can talk
## to, and build mode and its menu, which only show in play. Main calls it from `_process`, between
## its own steps.

## What it needs from Main is set after `new()`: it takes more than the ten arguments that
## `_init` may.
var state: GameState
var settings: GameSettings
var options: StartupOptions
var camera: CameraController
var builder: Builder
var blackout: BlackoutFlow
var use_highlight: UseHighlight
var build_mode: BuildMode
var build_menu: BuildMenu
var action_hint: ActionHintView
var tooltip_view: TooltipView
var npc_name_tag: NpcNameTag


## `is_in_play` is whether no window or console takes the input.
func update(is_in_play: bool) -> void:
	var viewport := camera.get_viewport()
	var is_pointer_on_gui := (
		Modal.is_any_open()
		and (viewport.gui_get_hovered_control() != null or viewport.gui_is_dragging())
	)
	use_highlight.is_pointer_on_gui = is_pointer_on_gui
	build_mode.is_pointer_on_gui = is_pointer_on_gui
	use_highlight.is_enabled = (
		is_in_play
		and not is_pointer_on_gui
		and not builder.is_building()
		and not blackout.is_in_transition
	)
	# On horseback E gets off instead.
	var can_act := is_in_play and not build_mode.is_active() and not blackout.is_in_transition
	var can_chat := can_act and state.player.horse == null
	var aim := use_highlight.targeting()
	action_hint.show_for(state, settings, aim.tile, can_act)
	var is_aiming_at_world := is_in_play and not is_pointer_on_gui and not builder.is_building()
	tooltip_view.world_text = WorldHoverText.text_for(state, aim, is_aiming_at_world)
	tooltip_view.world_cursor = (
		_mouse_in_ui_units(viewport)
		if aim.source == Targeting.Source.MOUSE
		else camera.world_to_ui((Vector2(aim.tile) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE)
	)
	npc_name_tag.show_over(Interaction.npc_to_chat(state, aim.tile) if can_chat else null, camera)
	# Build mode only counts outdoors, in play and not during a transition; it keeps processing,
	# to clear its message when it goes off.
	build_mode.visible = is_in_play and not state.is_inside() and not blackout.is_in_transition
	build_menu.visible = build_mode.is_active()


## Where the mouse is, in UI units; with `--mouse-tile`, the middle of that tile.
func _mouse_in_ui_units(viewport: Viewport) -> Vector2:
	if options.mouse_tile == StartupOptions.NO_TILE:
		return viewport.get_mouse_position()
	return camera.world_to_ui(
		(Vector2(options.mouse_tile) + Vector2(0.5, 0.5)) * TerrainTileset.TILE_SIZE
	)
