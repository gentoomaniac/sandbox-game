extends GutTest
## The stations file and its validation.

const DATA_DIR := "user://test_station_data"
const DATA_FILE := DATA_DIR + "/stations.cfg"


func after_each() -> void:
	for file_name in DirAccess.get_files_at(DATA_DIR):
		DirAccess.remove_absolute(DATA_DIR.path_join(file_name))


func _problems_of_objects(objects: Variant) -> Array[String]:
	return StationRules.new({"bench": {"name": "Bench", "objects": objects}}).problems()


func test_the_stations_file_is_valid_and_the_hearth_and_campfire_are_the_hearth() -> void:
	var rules := StationRules.from_file(StationRules.DEFAULT_PATH)
	assert_true(rules.is_valid(), str(rules.problems()))
	assert_eq(rules.station_of(WorldObjectTypes.HEARTH), &"hearth")
	assert_eq(rules.station_of(WorldObjectTypes.FIREPLACE), &"hearth")
	assert_eq(rules.station_name(&"hearth"), "Hearth")
	assert_eq(rules.station_of(WorldObjectTypes.CHEST), &"", "a chest is no station")


func test_every_missing_key_is_reported() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var file := FileAccess.open(DATA_FILE, FileAccess.WRITE)
	file.store_string('[hearth]\nname="Hearth"\n\n[bench]\nobjects=["table"]\n')
	file.close()
	var rules := StationRules.from_file(DATA_FILE)
	assert_eq(rules.problems(), ["[hearth] no objects", "[bench] no name"] as Array[String])
	assert_push_error_count(2)


func test_bad_objects_are_reported() -> void:
	assert_eq(_problems_of_objects([]).size(), 1, "none")
	assert_eq(_problems_of_objects("table").size(), 1, "not a list")
	assert_eq(
		_problems_of_objects(["throne"]), ["[bench] not an object type: throne"] as Array[String]
	)
	assert_eq(_problems_of_objects(["table", "stool"]), [] as Array[String])


func test_an_object_is_at_most_one_station() -> void:
	var stations := {
		"bench": {"name": "Bench", "objects": ["table"]},
		"desk": {"name": "Desk", "objects": ["table"]},
	}
	var rules := StationRules.new(stations)
	assert_eq(rules.problems(), ["[desk] table is already a station"] as Array[String])


func test_a_file_with_no_stations_is_invalid() -> void:
	assert_eq(StationRules.new({}).problems(), ["no stations"] as Array[String])
