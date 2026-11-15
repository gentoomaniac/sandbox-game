class_name MapScreen
extends Modal
## The world map, a test tool that the console's `map` opens and closes (Escape closes it too): the
## land from MapView, with the fog of war over what the player has not explored. A click on the map
## offers a teleport to that tile, which is the console's `tp`. The game goes on behind it, so
## that the villagers move on the map; only the player stands still, as with any window.
## See design/world/world-map.md.

## The room kept round the map, in canvas pixels.
const MARGIN := 12
## What the confirm keeps from the edges of the map, in pixels.
const CONFIRM_INSET := 8.0
const STATUS_GAP := 24
const HINT := "Click a spot to teleport there. Drag or arrow keys move the map, the wheel zooms."

## Teleports the player: takes a tile, returns the lines the console answers (set by the game
## scene, which runs the `tp` command).
var teleporter := Callable()

var _state: GameState
var _view := MapView.new()
var _tile_label := Label.new()
var _note := Label.new()
var _confirm := PanelContainer.new()
var _confirm_text := Label.new()
var _teleport_tile := Vector2i.ZERO


func _init() -> void:
	super()
	is_movable = false
	var box := VBoxContainer.new()
	_panel.add_child(box)
	box.add_child(_view)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", STATUS_GAP)
	status.add_child(_tile_label)
	status.add_child(_note)
	box.add_child(status)
	_view.tile_clicked.connect(_offer_teleport)
	_view.tile_hovered.connect(_show_tile)
	_build_confirm()
	_view.add_child(_confirm)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_window)
	_fit_to_window()


## The map of the game `state`: it is built at the first opening and kept.
func show_state(state: GameState) -> void:
	_state = state
	_view.show_state(state, MapBuilder.new(state.world, state.explored))


## Opens the map when it is closed and closes it when it is open: what the console's `map` does.
## Returns what to tell the player.
func toggled() -> String:
	toggle()
	return "Map opened" if is_open() else "Map closed"


func _on_open() -> void:
	_confirm.hide()
	_view.centre_on_player()
	_view.refresh()
	_note.text = HINT


func _takes_escape() -> bool:
	if not _confirm.visible:
		return false
	_confirm.hide()
	return true


## The map takes the window, less the room round the panel, its frame and the status line.
func _fit_to_window() -> void:
	var frame := _panel.get_theme_stylebox("panel").get_minimum_size()
	var status_height := _tile_label.get_combined_minimum_size().y
	var taken := Vector2.ONE * MARGIN * 2 + frame + Vector2(0, status_height)
	_view.custom_minimum_size = get_viewport().get_visible_rect().size - taken


func _build_confirm() -> void:
	_confirm.hide()
	var column := VBoxContainer.new()
	_confirm.add_child(column)
	column.add_child(_confirm_text)
	var row := HBoxContainer.new()
	column.add_child(row)
	var teleport := Button.new()
	teleport.text = "Teleport"
	teleport.focus_mode = Control.FOCUS_NONE
	teleport.pressed.connect(_teleport)
	row.add_child(teleport)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(_confirm.hide)
	row.add_child(cancel)


func _offer_teleport(tile: Vector2i, at: Vector2) -> void:
	_teleport_tile = tile
	_confirm_text.text = "Teleport to %d, %d?" % [tile.x, tile.y]
	_confirm.show()
	_confirm.reset_size()
	var room := _view.size - _confirm.size - Vector2.ONE * CONFIRM_INSET
	_confirm.position = (at + Vector2.ONE * CONFIRM_INSET).clamp(Vector2.ONE * CONFIRM_INSET, room)


## Does what `tp` does, and leaves the map when it worked.
func _teleport() -> void:
	_confirm.hide()
	var lines: Array = teleporter.call(_teleport_tile)
	if _state.player.tile() == _teleport_tile:
		close()
	elif not lines.is_empty():
		_note.text = lines[0]


func _show_tile(tile: Vector2i) -> void:
	_tile_label.text = "%d, %d" % [tile.x, tile.y]
