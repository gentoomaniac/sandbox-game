extends GutTest
## A deed done on the village's own land is told by its place and weighs otherwise (data/gossip.cfg
## [village_land]; design/world/wehlsbuell.md, section 9).

var _state: GameState
var _rules := GossipRules.default_rules()
var _tile: Vector2i


func before_each() -> void:
	_state = GameState.new_game(7)
	_tile = _state.player.tile()
	var feet := Vector2(_tile) + Vector2(3.5, 0.5)
	var antje := Npc.create_villager("antje", feet, _state.npcs.villagers)
	antje.anchor = feet
	_state.npcs.add(antje)


func _village_around_the_player() -> void:
	var village := Village.new()
	village.village_name = "Wehlsbüll"
	village.area = Rect2i(_tile - Vector2i(10, 10), Vector2i(20, 20))
	_state.world.village = village


func _deed_of(kind: StringName) -> Dictionary:
	var outcome_kind: StringName = {
		GossipRules.BUILT: ActionOutcome.BUILD,
		GossipRules.FENCED: ActionOutcome.PLACE,
		GossipRules.FELLED: ActionOutcome.BREAK,
		GossipRules.TOOK_DOWN: ActionOutcome.DEMOLISH,
	}[kind]
	var object: StringName = {
		GossipRules.BUILT: BuildingTypes.SHACK,
		GossipRules.FENCED: WorldObjectTypes.WATTLE_FENCE,
		GossipRules.FELLED: WorldObjectTypes.OAK,
		GossipRules.TOOK_DOWN: BuildingTypes.SHACK,
	}[kind]
	_state.report(outcome_kind, _tile, object, {})
	return _state.deeds.entries.back()


func test_a_deed_on_the_land_has_the_lands_place_and_the_lands_change() -> void:
	_village_around_the_player()
	var changes := {GossipRules.BUILT: -2, GossipRules.FENCED: -1, GossipRules.FELLED: -1}
	for kind: StringName in changes:
		var deed := _deed_of(kind)
		assert_eq(deed["place"], _rules.village_land_place(), str(kind))
		assert_eq(_rules.opinion_change(kind, deed["place"]), changes[kind], str(kind))
	assert_eq(_rules.opinion_change(GossipRules.BUILT), 1, "off the land it is the usual")


func test_the_witness_is_told_the_place_and_the_fixed_verdict_follows_it() -> void:
	_village_around_the_player()
	_deed_of(GossipRules.BUILT)
	var antje := _state.npcs.find("antje")
	assert_string_contains(
		_rules.story_line(antje.stories[0], 0), "build a house on the village's own land"
	)
	assert_eq(_state.judge.fixed_verdict(antje.stories[0])["change"], -2)


func test_a_kind_the_section_leaves_out_has_its_usual_change() -> void:
	_village_around_the_player()
	var deed := _deed_of(GossipRules.TOOK_DOWN)
	assert_eq(
		_rules.opinion_change(GossipRules.TOOK_DOWN, deed["place"]),
		_rules.opinion_change(GossipRules.TOOK_DOWN)
	)


func test_a_deed_outside_the_land_or_in_a_world_with_no_village_is_as_ever() -> void:
	var deed := _deed_of(GossipRules.BUILT)
	assert_eq(deed["place"], "by Antje's house")
	assert_eq(_state.judge.fixed_verdict(_state.npcs.find("antje").stories[0])["change"], 1)
	_village_around_the_player()
	_state.world.village.area = Rect2i(_tile + Vector2i(50, 50), Vector2i(20, 20))
	_state.deeds.entries.clear()
	assert_eq(_deed_of(GossipRules.BUILT)["place"], "by Antje's house")


func test_deeds_on_the_land_and_off_it_by_one_house_stay_two_entries() -> void:
	_deed_of(GossipRules.FELLED)
	_village_around_the_player()
	_deed_of(GossipRules.FELLED)
	assert_eq(_state.deeds.entries.size(), 2)
