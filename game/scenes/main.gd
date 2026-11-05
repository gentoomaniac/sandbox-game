extends Node2D
## Debug scene: a world with a camera moved by the arrow keys. The player replaces it.
##
## Debug flags (after `--` on the Godot command line, see `make screenshot`):
## `--at=<x>,<y>` starts the camera at that world tile; `--screenshot=<path>` saves one
## frame as PNG once streaming has settled, then quits.

const WORLD_SEED := 1
const CAMERA_SPEED := 240.0  # pixels per second

var _screenshot_path := ""

@onready var _view: WorldView = $WorldView
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_view.show_world(World.new(WORLD_SEED))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var tile := arg.trim_prefix("--at=").split_floats(",")
			_camera.position = Vector2(tile[0], tile[1]) * TerrainTileset.TILE_SIZE
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.trim_prefix("--screenshot=")


func _process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += direction * CAMERA_SPEED * delta
	_view.set_focus(Vector2i((_camera.position / TerrainTileset.TILE_SIZE).floor()))
	if _screenshot_path != "" and _view.is_settled:
		_save_screenshot_and_quit()


func _save_screenshot_and_quit() -> void:
	# Draws now instead of waiting for the next frame, which never comes while the window
	# can't be shown (e.g. a locked screen).
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
