class_name CheatFlags
extends RefCounted
## The cheats the console toggles. They last for the session: they are not saved and are off
## at the start of every game.

var is_god := false
var is_drain_off := false
var is_weight_off := false
var is_cost_off := false
var is_noclip := false
## The game clock stands still: no minutes pass, so the day, the crops and the weather wait.
var is_time_stopped := false


## The names of the cheats that are on, for the HUD.
func active_names() -> Array[String]:
	var names: Array[String] = []
	if is_god:
		names.append("God")
	if is_drain_off:
		names.append("No drain")
	if is_weight_off:
		names.append("No weight")
	if is_cost_off:
		names.append("No cost")
	if is_noclip:
		names.append("No clip")
	if is_time_stopped:
		names.append("Time stopped")
	return names
