extends GutTest
## The entry of a day that is on at a time (DayEntry `on`).


func _entry(activity: String, hour: int, minute: int, minutes := 0) -> DayEntry:
	return DayEntry.new(activity, hour * 60 + minute, minutes)


func test_the_entry_that_is_on_is_the_last_that_has_started() -> void:
	var today: Array[DayEntry] = [_entry("work", 6, 30, 330), _entry("dinner", 12, 0, 60)]
	assert_eq(DayEntry.on(today, [], 6 * 60 + 30).activity, "work")
	assert_eq(DayEntry.on(today, [], 11 * 60 + 59).activity, "work")
	assert_eq(DayEntry.on(today, [], 12 * 60).activity, "dinner")


func test_nothing_is_on_when_the_length_has_run_out() -> void:
	var today: Array[DayEntry] = [_entry("dinner", 12, 0, 60)]
	assert_eq(DayEntry.on(today, [], 12 * 60 + 59).activity, "dinner")
	assert_null(DayEntry.on(today, [], 13 * 60))


func test_an_entry_with_no_length_lasts_until_the_next() -> void:
	var today: Array[DayEntry] = [_entry("work", 6, 30), _entry("dinner", 12, 0)]
	assert_eq(DayEntry.on(today, [], 11 * 60).activity, "work")
	assert_eq(DayEntry.on(today, [], 23 * 60 + 59).activity, "dinner")


func test_before_the_first_entry_it_is_the_last_of_yesterday_if_it_still_lasts() -> void:
	var yesterday: Array[DayEntry] = [_entry("supper", 18, 0, 30), _entry("sleep", 21, 30, 450)]
	var today: Array[DayEntry] = [_entry("breakfast", 5, 30, 45)]
	assert_eq(DayEntry.on(today, yesterday, 0).activity, "sleep")
	assert_eq(DayEntry.on(today, yesterday, 4 * 60 + 59).activity, "sleep")
	assert_null(DayEntry.on(today, yesterday, 5 * 60), "slept out, breakfast not yet")
	assert_eq(DayEntry.on(today, yesterday, 5 * 60 + 30).activity, "breakfast")


func test_a_day_with_no_entries_has_nothing_on() -> void:
	assert_null(DayEntry.on([], [], 12 * 60))
