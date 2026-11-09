extends SceneTree
## Starts Main headless on a save, waits until the world view has settled and prints the time
## that took, the node count, the entity count, and the mean and longest frame over the next
## 300 frames. `make bench` runs it on a copy of the fixture save.
## godot --headless --path . -s tools/bench/frames.gd -- --save-path=<save> --settings-path=<s> --mute

var main: Node
var frame := 0
var t0 := 0
var settled_at := -1
var times: Array[float] = []
var last := 0


func _initialize() -> void:
	main = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(main)
	t0 = Time.get_ticks_usec()
	last = t0


func _process(_d: float) -> bool:
	frame += 1
	var now := Time.get_ticks_usec()
	if settled_at < 0 and main._view.is_settled:
		settled_at = frame
		print("settled: frame ", frame, " after ms ", (now - t0) / 1000.0)
	if settled_at >= 0:
		times.append((now - last) / 1000.0)
	last = now
	if settled_at >= 0 and frame == settled_at + 5:
		print("nodes ", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var sprites := 0
		for c in main._view.entities.get_children():
			if c is Sprite2D:
				sprites += 1
		print("entities children ", main._view.entities.get_child_count(), " pile sprites ", sprites)
	if settled_at >= 0 and frame == settled_at + 300:
		var sum := 0.0
		var mx := 0.0
		for t in times.slice(5):
			sum += t
			mx = maxf(mx, t)
		print("frame ms mean ", sum / (times.size() - 5), " max ", mx)
		quit()
	if frame > 3000:
		print("never settled")
		quit()
	return false
