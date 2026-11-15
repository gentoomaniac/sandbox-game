extends GutTest
## The swing's rules (data/tool_swing.cfg): which tool makes which motion and when its frames and
## its blow come.

var _rules := ToolSwingRules.default_rules()


func test_the_data_file_is_complete() -> void:
	assert_eq(_rules.problems(), [])


func test_every_tool_that_can_be_held_has_a_motion() -> void:
	for tool_kind in [
		ItemTypes.AXE,
		ItemTypes.PICKAXE,
		ItemTypes.HOE,
		ItemTypes.HAMMER,
		ItemTypes.SHOVEL,
		ItemTypes.SCYTHE,
		ItemTypes.WATERING_CAN,
	]:
		assert_ne(_rules.motion_of(tool_kind), &"", str(tool_kind))


func test_what_is_not_a_tool_makes_no_motion() -> void:
	assert_eq(_rules.motion_of(&""), &"")
	assert_eq(_rules.motion_of(&"lantern"), &"")


func test_the_motions_follow_each_other_in_the_columns() -> void:
	assert_eq(_rules.first_column(&"chop"), 0)
	assert_eq(_rules.first_column(&"knock"), _rules.frame_count(&"chop"))
	assert_eq(_rules.first_column(&"pour"), _rules.column_count() - _rules.frame_count(&"pour"))


func test_a_frame_shows_from_the_time_the_frames_before_it_took() -> void:
	var rules := _rules_of({"tools": ["axe"], "frame_ms": [100, 200, 50], "strike_frame": 1})
	assert_eq(rules.frame_start(&"chop", 0), 0.0)
	assert_almost_eq(rules.frame_start(&"chop", 2), 0.3, 0.0001)
	assert_almost_eq(rules.duration(&"chop"), 0.35, 0.0001)
	assert_eq(rules.frame_at(&"chop", 0.05), 0)
	assert_eq(rules.frame_at(&"chop", 0.1), 1)
	assert_eq(rules.frame_at(&"chop", 0.34), 2)
	assert_eq(rules.frame_at(&"chop", 9.0), 2, "after the end it stays on the last frame")


func test_a_blow_after_the_last_frame_is_reported() -> void:
	var rules := _rules_of({"tools": ["axe"], "frame_ms": [100], "strike_frame": 1})
	assert_eq(rules.problems(), ["[chop] strike_frame is no frame of the swing"])


func test_a_missing_key_is_reported() -> void:
	var rules := _rules_of({"tools": ["axe"], "frame_ms": [100]})
	assert_eq(rules.problems(), ["[chop] no strike_frame"])


func _rules_of(chop: Dictionary) -> ToolSwingRules:
	return ToolSwingRules.new({"chop": chop})
