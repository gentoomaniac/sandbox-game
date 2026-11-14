class_name CampfireUpkeep
extends SimulationSystem
## Burns the wood of the campfires down (task 56), in loaded chunks or not, over the minutes of play
## as over sleep and skips alike. A fire that burns out is drawn again, dark, as one that gets
## wood is (see Campfire).

var _world: World


func _init(world: World) -> void:
	_world = world


func advance(minutes: int, _clock: GameClock) -> void:
	for fire in _world.campfires():
		if Campfire.is_out(fire):
			continue
		if Campfire.burn(fire, minutes):
			_world.change_object(fire)
