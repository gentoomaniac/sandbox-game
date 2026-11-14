extends GutTest
## What searches on worker threads share with the main thread: the tide's kept heights and the
## vegetation's last densities, which answer the same from many threads at once.

const TASKS := 8
const QUESTIONS := 400


func _ask_the_tide(tile_row: int, answers: Array[float]) -> void:
	for x in QUESTIONS:
		answers[x] = Tide.flood_height(Vector2i(x, tile_row))


func test_the_flood_height_is_the_same_asked_from_many_threads() -> void:
	var expected: Array[float] = []
	for x in QUESTIONS:
		expected.append(Tide.flood_height(Vector2i(x, 5000)))
	var answers: Array = []
	var tasks: Array[int] = []
	for task in TASKS:
		var mine: Array[float] = []
		mine.resize(QUESTIONS)
		answers.append(mine)
		tasks.append(WorkerThreadPool.add_task(_ask_the_tide.bind(5000, mine)))
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	for mine: Array[float] in answers:
		assert_eq(mine, expected)


func _ask_the_vegetation(vegetation: Vegetation, days: int, shown: Array[bool]) -> void:
	for day in days:
		shown[day] = vegetation.is_present(WorldObjectTypes.FERN_BUSH, 7, Vector2i(3, 4), day + 1)


func test_the_vegetation_answers_the_same_from_many_threads() -> void:
	var vegetation := Vegetation.default_vegetation()
	var expected: Array[bool] = []
	for day in GameClock.DAYS_PER_YEAR:
		expected.append(
			vegetation.is_present(WorldObjectTypes.FERN_BUSH, 7, Vector2i(3, 4), day + 1)
		)
	var answers: Array = []
	var tasks: Array[int] = []
	for task in TASKS:
		var mine: Array[bool] = []
		mine.resize(GameClock.DAYS_PER_YEAR)
		answers.append(mine)
		tasks.append(
			WorkerThreadPool.add_task(
				_ask_the_vegetation.bind(vegetation, GameClock.DAYS_PER_YEAR, mine)
			)
		)
	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	for mine: Array[bool] in answers:
		assert_eq(mine, expected)
