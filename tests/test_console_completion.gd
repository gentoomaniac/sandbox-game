extends EnergyCase
## Tab completion in the console.

var _console: Console


func before_each() -> void:
	super.before_each()
	_console = Console.new(_state)


func test_complete_a_command_name() -> void:
	assert_eq(_console.complete("gi"), "give ")
	assert_eq(_console.complete("/no"), "/no")
	assert_eq(_console.complete("/nod"), "/nodrain ")


func test_complete_goes_as_far_as_the_candidates_agree() -> void:
	assert_eq(_console.complete("n"), "no")


func test_complete_an_item_after_give() -> void:
	assert_eq(_console.complete("give tur"), "give turnip")
	assert_eq(_console.complete("give sto"), "give stone ")
	assert_eq(_console.complete("/give pick"), "/give pickaxe ")


func test_complete_leaves_other_words_alone() -> void:
	assert_eq(_console.complete("give wood 5"), "give wood 5")
	assert_eq(_console.complete("tp 1"), "tp 1")
	assert_eq(_console.complete("give zzz"), "give zzz")
