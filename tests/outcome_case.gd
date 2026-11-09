class_name OutcomeCase
extends ResourceCase
## What the tests of action outcomes share: the outcomes the game told, and the check that exactly
## one was told.

var _outcomes: Array[ActionOutcome] = []


func before_each() -> void:
	super.before_each()
	_outcomes.clear()
	_state.action_done.connect(func(outcome: ActionOutcome) -> void: _outcomes.append(outcome))


func _assert_one(kind: StringName, tile: Vector2i, object := &"", items := {}) -> void:
	assert_eq(_outcomes.size(), 1, "one outcome for %s" % kind)
	if _outcomes.size() != 1:
		return
	var outcome := _outcomes[0]
	assert_eq(outcome.actor, ActionOutcome.PLAYER)
	assert_eq(outcome.kind, kind)
	assert_eq(outcome.tile, tile)
	assert_same(outcome.map, _state.current_map)
	assert_eq(outcome.object, object)
	assert_eq(outcome.items, items)
