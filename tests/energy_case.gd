class_name EnergyCase
extends ResourceCase
## What the energy tests share: a game that runs on the test's own rules, with numbers that
## differ from data/energy.cfg so nothing can pass by using the wrong ones.

const RULES := {
	"cost": {"till": 4.0, "hit": 3.0, "water": 2.0, "plant": 1.0, "pick": 0.5},
	"weight": {"free_kg": 12.0, "step_kg": 5.0, "extra_per_step": 0.5},
	"sleep": {"sleeping_bag": 80.0, "small_bed": 100.0},
	"food": {"berries": 3.0, "turnip": 8.0},
	"walk":
	{"slow_energy": 30.0, "slow_speed": 0.8, "very_slow_energy": 15.0, "very_slow_speed": 0.4},
	"debuff": {"walk_speed": 0.6, "energy_max": 40.0, "health": 20.0},
	"bars": {"warning": 25.0},
}


func before_each() -> void:
	super.before_each()
	_state.energy_rules = EnergyRules.new(RULES)


func _bed() -> WorldObject:
	return _world.object_at(_state.player.home_bed)
