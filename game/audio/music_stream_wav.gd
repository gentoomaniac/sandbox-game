class_name MusicStreamWAV
extends AudioStreamWAV
## Rendered music: an AudioStreamWAV that tells its beat. AudioStreamWAV has no BPM of its own, so
## AudioStreamInteractive would switch from it at once instead of on the next beat or bar; these
## overrides are all it needs (task 169 checked it on Godot 4.7.2). But played with Main running, a
## script subclass of AudioStreamWAV makes the game abort when it quits (docs/music-viability.md).

var bpm := 0.0
var beat_count := 0
var bar_beats := 4


func _get_bpm() -> float:
	return bpm


func _get_beat_count() -> int:
	return beat_count


func _get_bar_beats() -> int:
	return bar_beats
