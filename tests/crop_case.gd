class_name CropCase
extends GutTest
## Helpers for the crop tests: crops, their needs, and days that meet them.


func _crop(type: StringName = WorldObjectTypes.TURNIP) -> WorldObject:
	return WorldObject.new(type, Vector2i.ZERO)


func _need(crop: WorldObject, key: String) -> float:
	return crop.type_data()[key]


## A day that meets every need of the crop at its best: a growth score of 1.
func _best_day(crop: WorldObject) -> WeatherDay:
	var day := WeatherDay.new()
	day.mean_temperature = _need(crop, "temperature_best")
	day.min_temperature = _need(crop, "temperature_min") + 2.0
	day.max_temperature = _need(crop, "temperature_best") + 4.0
	day.sunlight_hours = _need(crop, "sunlight_best")
	day.max_wind_speed = 1.0
	return day


func _best_moisture(crop: WorldObject) -> float:
	return _need(crop, "moisture_best")


func _live(crop: WorldObject, day: WeatherDay, days := 1) -> void:
	for _i in days:
		CropLife.live_through_day(crop, day, _best_moisture(crop))
