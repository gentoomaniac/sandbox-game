extends Node2D
## Debug scene: a world with a camera moved by the arrow keys. The player replaces it.
##
## Debug flags (after `--` on the Godot command line, see `make screenshot`):
## `--at=<x>,<y>` starts the camera at that world tile; `--screenshot=<path>` saves one
## frame as PNG once streaming has settled, then quits; `--time=<hh:mm>` sets the time of
## day.

const WORLD_SEED := 1
const CAMERA_SPEED := 240.0  # pixels per second
## One game day lasts 16 real minutes (24 h * 60 min / 1.5 / 60 s).
const GAME_MINUTES_PER_REAL_SECOND := 1.5
## Debug speed-up, toggled with F2: a game day in 16 real seconds.
const FAST_FORWARD_FACTOR := 60.0

var clock := GameClock.new()

var _screenshot_path := ""
var _fast_forward := false
var _pending_minutes := 0.0

@onready var _view: WorldView = $WorldView
@onready var _camera: Camera2D = $Camera2D
@onready var _tint: DayNightTint = $DayNightTint
@onready var _hud: ClockHud = $ClockHud


func _ready() -> void:
	_view.show_world(World.new(WORLD_SEED))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			var tile := arg.trim_prefix("--at=").split_floats(",")
			_camera.position = Vector2(tile[0], tile[1]) * TerrainTileset.TILE_SIZE
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--time="):
			var time := arg.trim_prefix("--time=").split_floats(":")
			clock.set_time(int(time[0]), int(time[1]))
	_show_clock()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fast_forward"):
		_fast_forward = not _fast_forward


func _process(delta: float) -> void:
	_tick_clock(delta)
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += direction * CAMERA_SPEED * delta
	_view.set_focus(Vector2i((_camera.position / TerrainTileset.TILE_SIZE).floor()))
	if _screenshot_path != "" and _view.is_settled:
		_save_screenshot_and_quit()


## Real time to whole game minutes; the fraction carries over to the next frame.
func _tick_clock(delta: float) -> void:
	var rate := GAME_MINUTES_PER_REAL_SECOND * (FAST_FORWARD_FACTOR if _fast_forward else 1.0)
	_pending_minutes += delta * rate
	var whole_minutes := int(_pending_minutes)
	if whole_minutes > 0:
		_pending_minutes -= whole_minutes
		clock.advance(whole_minutes)
		_show_clock()


func _show_clock() -> void:
	_tint.show_time(clock)
	_hud.show_time(clock)


func _save_screenshot_and_quit() -> void:
	# Draws now instead of waiting for the next frame, which never comes while the window
	# can't be shown (e.g. a locked screen).
	RenderingServer.force_draw(false)
	get_viewport().get_texture().get_image().save_png(_screenshot_path)
	get_tree().quit()
