class_name CropWarnings
extends SimulationSystem
## Warns the player before a loss that can still be stopped: crops on soil so dry that they are
## about to be hurt (the watering can stops that), and ripe crops about to wither (the harvest
## does). Every hour it looks at the crops near the player. Crops in trouble the same way that
## stand together are one field, and a field is warned about once, not per tile and not every
## hour: again only after it was out of trouble. Numbers: data/crops.cfg, [farming] (CropRules).

signal warned(text: String)

var _world: World
## Where the player stands, in tiles (Vector2.INF when away): takes nothing.
var _player_feet: Callable
## Per kind of trouble: the tiles of the crops it has been warned about and that still are in it.
var _warned := {&"dry": {}, &"ripe": {}}


func _init(world: World, player_feet: Callable) -> void:
	_world = world
	_player_feet = player_feet


func advance(_minutes: int, clock: GameClock) -> void:
	if is_hour_end(clock):
		look_at_crops()


## Warns about every field that has just come to be in trouble.
func look_at_crops() -> void:
	var rules := CropRules.default_rules()
	var player_feet: Vector2 = _player_feet.call()
	var in_trouble := {&"dry": [], &"ripe": []}
	for crop in _world.crops():
		if (
			CropLife.is_dead(crop)
			or Vector2(crop.pos).distance_to(player_feet) > rules.farming("warn_within_tiles")
		):
			continue
		var driest_ok: float = crop.type_data()["moisture_min"] + rules.farming("warn_dry_margin")
		if _world.moisture_at(crop.pos) < driest_ok:
			in_trouble[&"dry"].append(crop)
		if (
			CropLife.is_ripe(crop)
			and CropLife.days_until_withering(crop) <= rules.farming("warn_wither_nights")
		):
			in_trouble[&"ripe"].append(crop)
	for trouble: StringName in in_trouble:
		_warn_about_new_fields(trouble, in_trouble[trouble])


## Tells the player about the fields of `crops` (all in the same `trouble`) that have no crop
## that was warned about before.
func _warn_about_new_fields(trouble: StringName, crops: Array) -> void:
	var warned_tiles: Dictionary = _warned[trouble]
	var tiles_in_trouble := {}
	for crop: WorldObject in crops:
		tiles_in_trouble[crop.pos] = true
	for tile: Vector2i in warned_tiles.keys():
		if not tiles_in_trouble.has(tile):
			warned_tiles.erase(tile)
	for field in _fields(crops):
		var is_new := true
		for crop: WorldObject in field:
			is_new = is_new and not warned_tiles.has(crop.pos)
			warned_tiles[crop.pos] = true
		if is_new:
			warned.emit(_warning(trouble, field))


## The crops that stand within `field_gap_tiles` of each other, one list per field.
func _fields(crops: Array) -> Array[Array]:
	var gap: int = CropRules.default_rules().farming("field_gap_tiles")
	var unsorted := crops.duplicate()
	var fields: Array[Array] = []
	while not unsorted.is_empty():
		var field: Array = [unsorted.pop_back()]
		var next_in_field := 0
		while next_in_field < field.size():
			var member: WorldObject = field[next_in_field]
			next_in_field += 1
			for other: WorldObject in unsorted.duplicate():
				var apart: Vector2i = (other.pos - member.pos).abs()
				if maxi(apart.x, apart.y) <= gap:
					unsorted.erase(other)
					field.append(other)
		fields.append(field)
	return fields


func _warning(trouble: StringName, field: Array) -> String:
	var crop_name: String = field[0].type_data()["name"].to_lower()
	if trouble == &"dry":
		return "The %s field is drying out: water it" % crop_name
	var nights_left := 99
	for crop: WorldObject in field:
		nights_left = mini(nights_left, CropLife.days_until_withering(crop))
	return (
		"The %s field is ripe and will wither %s: harvest it"
		% [crop_name, CropWords.withers_in(nights_left)]
	)
