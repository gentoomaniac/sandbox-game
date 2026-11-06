class_name EnergyCase
extends ResourceCase
## What the energy tests share: a game that runs on the test's own rules, with numbers that
## differ from data/energy.cfg so nothing can pass by using the wrong ones.

const RULES := {
	"cost":
	{"till": 4.0, "hit": 3.0, "water": 2.0, "plant": 1.0, "pick": 0.5, "mow": 3.5, "dig": 2.5},
	"weight": {"free_kg": 20.0, "step_kg": 5.0, "extra_per_step": 0.5},
	"sleep": {"sleeping_bag": 80.0, "small_bed": 100.0},
	"food": {"berries": 3.0, "turnip": 8.0},
	"walk":
	{"slow_energy": 30.0, "slow_speed": 0.8, "very_slow_energy": 15.0, "very_slow_speed": 0.4},
	"debuff": {"walk_speed": 0.6, "energy_max": 40.0, "health": 20.0},
	"bars": {"warning": 25.0},
	"signs":
	{"tired": 30.0, "exhausted": 12.0, "late_first_minute": 15.0, "late_second_minute": 45.0},
}


func before_each() -> void:
	super.before_each()
	_state.energy_rules = EnergyRules.new(RULES)


func _bed() -> WorldObject:
	return _world.object_at(_state.player.home_bed)


## Walks into a new house, sleeps in its bed (making it home) and walks out again.
func _make_a_house_home() -> WorldObject:
	var house: Building
	for y in range(-12, 13):
		for x in range(-12, 13):
			house = (
				house
				if house != null
				else _world.place_building(
					BuildingTypes.KATE, _state.player.tile() + Vector2i(x, y)
				)
			)
	_state.player.position = Vector2(house.door_tile()) + Vector2(0.5, 0.5)
	_state.pass_door()
	var bed: WorldObject = house.interior.object_at(Vector2i(1, 2))
	_state.player.position = Vector2(2.5, 3.5)
	_state.sleep_in(bed)
	_state.player.position = Vector2(house.interior.exit_tile) + Vector2(0.5, 0.5)
	_state.pass_door()
	return bed
