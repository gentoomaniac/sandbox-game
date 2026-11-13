class_name CropRaidCase
extends ResourceCase
## What the tests of the crows' raids share: a field of crops, a flock of crows on it, and rules
## made up for the test where the real chances would make it chancy.

const FIELD_WIDTH := 8
const HOUR := 10
const SURE := {
	"player_tiles": 12.0,
	"hour_chance": 1.0,
	"reach_tiles": 3,
	"crops_per_raid": 2,
	"stage_chances": [1.0, 1.0, 1.0, 1.0],
	"whole_up_to_stage": 0,
	"max_plants_per_day": 100,
	"max_items_per_day": 100,
	"sown_boost_per_crop": 0.1,
	"sown_boost_max": 3.0,
	"sown_radius_tiles": 6,
}

var _raids: CropRaids
var _player_feet := Vector2.INF
var _field: Array[WorldObject] = []


func before_each() -> void:
	super.before_each()
	_raids = _raids_with({})
	_field = []


func _raids_with(changes: Dictionary) -> CropRaids:
	var values := SURE.duplicate()
	values.merge(changes, true)
	return CropRaids.new(_world, func() -> Vector2: return _player_feet, CropRaidRules.new(values))


## A row of crops of a type on soil, each grown to a stage, from the test's tile eastwards.
func _plant_row(crop_type: StringName, stage: int, count := FIELD_WIDTH) -> void:
	for x in count:
		var pos := _tile + Vector2i(x, 0)
		_world.remove_object(pos)
		_world.set_terrain(pos, Tile.Terrain.SOIL)
		var crop := WorldObject.new(crop_type, pos)
		crop.state["growth"] = stage * crop.type_data()["growth_per_stage"]
		_world.add_object(crop)
		_field.append(crop)


func _crops_left() -> int:
	return (
		_field
		. filter(func(crop: WorldObject) -> bool: return _world.object_at(crop.pos) != null)
		. size()
	)


func _items_eaten() -> int:
	var items := 0
	for crop in _field:
		items += CropLife.eaten(crop)
	return items
