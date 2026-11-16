extends GutTest
## Main puts every feature flow that FeatureFlows makes into the game scene's tree: a flow it
## forgets would register its kind of E (the hint says it) but open no screen.

const MAIN_SCENE := preload("res://game/scenes/main.tscn")
const SETTLE_SECONDS := 30.0


func test_every_feature_flow_is_in_the_tree_of_main() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await wait_until(
		func() -> bool: return main._view != null and main._view.is_settled, SETTLE_SECONDS
	)

	for flow: Node in main._flows.all():
		assert_true(main.is_ancestor_of(flow), "%s is not in Main's tree" % flow.name)

	main._saves.wait()
	main.free()
