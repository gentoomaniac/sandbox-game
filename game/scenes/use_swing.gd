class_name UseSwing
extends RefCounted
## Lets the use of a tool take the time of its swing (see PlayerView `swing`): the character swings
## and the tile is used when the blow lands, the strike frame of data/tool_swing.cfg. The energy,
## the sounds and the skill all follow `used`, so they come with the blow.
##
## Until the swing is over the player can use nothing else: `use_on` refuses. A use of something
## that is no swing (an empty hand, seeds, a tool at a tile it does nothing on) is done at once.

## A tile was used with the held item, with this result (see GameState `use_tile`).
signal used(result: ToolUse.Use, tile: Vector2i)

var _state: GameState
var _view: PlayerView
## What the swing in progress is for: the tile, and the item in hand when it began, so that a
## player who changes the item meanwhile does not use another one.
var _tile := Vector2i.ZERO
var _item := ItemTypes.NONE


func _init(state: GameState, view: PlayerView) -> void:
	_state = state
	_view = view
	view.swing_struck.connect(_on_struck)


## Uses the targeted tile: at once, or with a swing (see `used`). Returns false for a use refused
## because the player is still swinging.
func use_on(target: Targeting) -> bool:
	if _view.is_swinging():
		return false
	var item := _state.player.inventory.held_item()
	var tool_kind: StringName = ItemTypes.TYPES.get(item, {}).get("tool", &"")
	var motion := ToolSwingRules.default_rules().motion_of(tool_kind)
	if (
		motion == &""
		or not target.is_in_reach
		or not _state.use_at(target.tile) in ToolUse.SWUNG_USES
	):
		used.emit(_state.use_tile(target.tile), target.tile)
		return true
	_tile = target.tile
	_item = item
	_view.swing(motion)
	return true


func _on_struck() -> void:
	if _state.player.inventory.held_item() == _item:
		used.emit(_state.use_tile(_tile), _tile)
