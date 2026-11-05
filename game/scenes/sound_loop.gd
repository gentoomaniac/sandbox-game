class_name SoundLoop
extends RefCounted
## A looping sound that keeps playing until it is stopped (rain, wind, a bee's buzz), from
## `AudioService.start_loop`. Its level is a share of the event's own volume, 0 (silent) to 1,
## and changes over time with `fade_to`. A stopped loop is finished: start a new one instead.

var _player: Node
var _base_volume_db: float
var _tween: Tween


## `player` is an AudioStreamPlayer or an AudioStreamPlayer2D that is already playing.
func _init(player: Node, base_volume_db: float, level: float) -> void:
	_player = player
	_base_volume_db = base_volume_db
	_player.volume_db = _db_of(level)


## Moves a positional loop (a loop without a position does not move).
func move_to(position: Vector2) -> void:
	if is_instance_valid(_player) and _player is AudioStreamPlayer2D:
		_player.position = position


## Fades to `level` over `seconds`. Does nothing after `stop`.
func fade_to(level: float, seconds: float) -> void:
	if not is_instance_valid(_player):
		return
	if _tween != null:
		_tween.kill()
	_tween = _player.create_tween()
	_tween.tween_property(_player, "volume_db", _db_of(level), seconds)


## Fades out over `seconds`, then ends the loop.
func stop(seconds := 0.0) -> void:
	if not is_instance_valid(_player):
		return
	fade_to(0.0, seconds)
	_tween.tween_callback(_player.queue_free)


func _db_of(level: float) -> float:
	return _base_volume_db + AudioService.percent_to_db(level * 100.0)
