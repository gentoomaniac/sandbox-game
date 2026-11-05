extends Node2D
## Debug scene: a world with a camera moved by the arrow keys. The player replaces it.

const WORLD_SEED := 1
const CAMERA_SPEED := 240.0  # pixels per second

@onready var _view: WorldView = $WorldView
@onready var _camera: Camera2D = $Camera2D


func _ready() -> void:
	_view.show_world(World.new(WORLD_SEED))


func _process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	_camera.position += direction * CAMERA_SPEED * delta
	_view.set_focus(Vector2i((_camera.position / PlaceholderTileset.TILE_SIZE).floor()))
