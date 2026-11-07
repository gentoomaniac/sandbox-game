extends ResourceCase
## The saddle: the console gives one.


func test_the_console_gives_a_saddle() -> void:
	var lines := Console.new(_state).run("give saddle")
	assert_eq(lines, ["Gave 1 Saddle"] as Array[String])
	assert_eq(_state.player.inventory.count_of(ItemTypes.SADDLE), 1)
