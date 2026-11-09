extends Node
## Ticks an AutosaveTimer from _process as Main does, for tests/test_autosave.gd.

var timer: AutosaveTimer
var counted := 0.0


func _process(delta: float) -> void:
	timer.tick(delta)
	counted += delta
