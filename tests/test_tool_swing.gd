extends ResourceCase
## The swing of the character (PlayerView): it plays the motion of a tool for the way the player
## faces and stands again, the blow lands at the strike frame, and from behind the can is drawn
## over the body.

const STEP := 0.01
const USE_BODY := "res://assets/character/use/body_0.png"

var _view: PlayerView
var _rules := ToolSwingRules.default_rules()


func before_each() -> void:
	super.before_each()
	_view = PlayerView.new()
	add_child_autofree(_view)
	_view.show_player(_state.player)
	_state.player.facing = Vector2i.DOWN


func after_each() -> void:
	ArtSet.is_classic = false


func test_the_swing_plays_its_frames_and_ends_standing() -> void:
	watch_signals(_view)
	_view.swing(&"chop")
	_run(0.01)
	assert_true(_view.is_swinging())
	assert_eq(_shown_frame(), _sheet_frame(&"chop", 0, Vector2i.DOWN))
	_run(0.1)
	assert_eq(_shown_frame(), _sheet_frame(&"chop", 1, Vector2i.DOWN))
	_run(_rules.duration(&"chop"))
	assert_false(_view.is_swinging())
	assert_signal_emit_count(_view, "swing_ended", 1)
	assert_eq(_shown_frame(), PlayerView.frame_index(Vector2i.DOWN, PlayerView.IDLE_COLUMN))


func test_the_swing_faces_the_way_the_player_faced_when_it_began() -> void:
	_state.player.facing = Vector2i.LEFT
	_view.swing(&"dig")
	_state.player.facing = Vector2i.UP
	_run(0.01)
	assert_eq(_shown_frame(), _sheet_frame(&"dig", 0, Vector2i.LEFT))


func test_the_blow_lands_when_the_strike_frame_begins() -> void:
	watch_signals(_view)
	_view.swing(&"chop")
	var strike_time := _rules.frame_start(&"chop", _rules.strike_frame(&"chop"))
	_run(strike_time - 2 * STEP)
	assert_signal_not_emitted(_view, "swing_struck")
	_run(3 * STEP)
	assert_signal_emit_count(_view, "swing_struck", 1)
	_run(_rules.duration(&"chop"))
	assert_signal_emit_count(_view, "swing_struck", 1, "once")


func test_facing_up_the_axe_is_behind_the_body_and_the_can_over_it() -> void:
	_state.player.facing = Vector2i.UP
	assert_eq(_held_layers_over_the_body(&"axe", &"chop"), 0)
	assert_eq(_held_layers_over_the_body(&"watering_can", &"pour"), _rules.frame_count(&"pour"))


func test_every_layer_of_the_swing_has_the_columns_of_all_motions() -> void:
	for is_classic in [false, true]:
		ArtSet.is_classic = is_classic
		var sheet: Texture2D = load(ArtSet.path(USE_BODY))
		var cell := PlayerView.SWING_CELL
		assert_eq(
			sheet.get_size(),
			Vector2(cell * _rules.column_count(), cell * PlayerView.FACING_ROWS.size()),
			"classic: %s" % is_classic
		)


## How many frames of the motion, seen from behind, draw the tool of that kind in front of the
## body: its front sheet has something in them. Where it is behind, the behind sheet has.
func _held_layers_over_the_body(tool_kind: StringName, motion: StringName) -> int:
	var variant: String = ItemTypes.TYPES[ItemTypes.tool_item(tool_kind, 0)]["held_sheet"]
	var front: Image = (
		load(Appearance.use_sheet_path({slot = Appearance.HELD, variant = variant})).get_image()
	)
	var count := 0
	for frame in _rules.frame_count(motion):
		var cell := Rect2i(
			(_rules.first_column(motion) + frame) * PlayerView.SWING_CELL,
			PlayerView.FACING_ROWS[Vector2i.UP] * PlayerView.SWING_CELL,
			PlayerView.SWING_CELL,
			PlayerView.SWING_CELL
		)
		if not front.get_region(cell).is_invisible():
			count += 1
	return count


func _shown_frame() -> int:
	return _view._sprites[0].frame


func _sheet_frame(motion: StringName, frame: int, facing: Vector2i) -> int:
	return (
		PlayerView.FACING_ROWS[facing] * _rules.column_count() + _rules.first_column(motion) + frame
	)


## Lets the view process frames of STEP seconds for `seconds`.
func _run(seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_view._process(STEP)
