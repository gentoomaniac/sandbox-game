class_name Scarecrows
extends RefCounted
## What the player's scarecrows guard from the crows (task 226; the numbers are in data/crows.cfg,
## see CropRaidRules). A scarecrow guards the tiles within its radius, fully for a few days after
## it was put down (its `placed_day`), then less as the crows get used to it, down to a floor.
## Taking it down and putting it up again starts it anew. Where it stands is only an object of
## the world; nothing here is saved.

var _world: World
var _rules: CropRaidRules


func _init(world: World, rules := CropRaidRules.default_rules()) -> void:
	_world = world
	_rules = rules


## How strongly a tile is guarded, from 0 to 1: that of the strongest scarecrow in whose radius it
## lies. It is the chance that the crows keep away from the tile for the day.
func strength_at(tile: Vector2i) -> float:
	var radius := _rules.value("scarecrow_radius_tiles")
	var strongest := 0.0
	for scarecrow in _world.scarecrows():
		if Vector2(scarecrow.pos).distance_to(Vector2(tile)) <= radius:
			strongest = maxf(strongest, strength_of(scarecrow))
	return strongest


## How strongly a scarecrow guards, from 0 to 1, by the days it has stood.
func strength_of(scarecrow: WorldObject) -> float:
	return _rules.scarecrow_strength(_world.clock.day - placed_day_of(scarecrow))


## The day a scarecrow was put down; today for one that has no day (it counts as new).
func placed_day_of(scarecrow: WorldObject) -> int:
	return int(scarecrow.state.get("placed_day", _world.clock.day))


## Whether a tile is guarded today, which is the same all day: the day's dice for the tile against
## its strength.
func is_guarding(tile: Vector2i) -> bool:
	return PositionHash.rolls(tile, _world.clock.day, strength_at(tile))


## What the console shows: each scarecrow, its strength, and how many crops in its radius are
## guarded today (by it or another).
func describe() -> Array[String]:
	var lines: Array[String] = []
	var radius := _rules.value("scarecrow_radius_tiles")
	for scarecrow in _world.scarecrows():
		var covered := 0
		var guarded := 0
		for crop in _world.crops():
			if Vector2(scarecrow.pos).distance_to(Vector2(crop.pos)) <= radius:
				covered += 1
				guarded += int(is_guarding(crop.pos))
		var line := (
			"Scarecrow at %d, %d, put down on day %d, strength %.2f: "
			% [scarecrow.pos.x, scarecrow.pos.y, placed_day_of(scarecrow), strength_of(scarecrow)]
		)
		lines.append(line + "%d crops in its radius, %d guarded today" % [covered, guarded])
	if lines.is_empty():
		lines.append("No scarecrows")
	return lines
