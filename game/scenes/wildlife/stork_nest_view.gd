class_name StorkNestView
extends Node2D
## The nest of storks on the ridge of a building, as the date has it (see StorkNests): the heap
## of sticks, the young over its rim (heads, then standing and flapping on it) and the pair, which
## are Storks on the nest that fly off to the meadows and come back. The WildlifeView makes one for
## each nest near the view and calls `update` every second.
##
## The nest stands in front of its house, sorted with it, like a stork on a roof; it is added to the
## view before the storks on it, so they are drawn over it.

## How high the rim of the nest is above its foot, in pixels: where the pair stands.
const RIM_HEIGHT := 10.0
## The pair stands this far to either side of the middle of the nest.
const PARENT_SPACING := 7
## The young stand this far apart, and the grown ones on the rim this high above the nest's foot.
const CHICK_SPACING := 8.0
const CHICK_MOST := 4
## The growth (see StorkNests.Occupants) from which the young look half grown, and grown.
const HALF_GROWN_FROM := 0.34
const GROWN_FROM := 0.67
## A grown young stands on the rim for this long, in seconds, then flaps for the next, at random.
const STAND_SECONDS := Vector2(5.0, 14.0)
const FLAP_SECONDS := Vector2(2.0, 4.0)
const FLAP_FRAMES_PER_SECOND := 5.0
## The frames of a wingbeat: up, level, down and level again.
const BEAT_FRAMES: Array[int] = [0, 1, 2, 1]
const LOOK_ROUND_SECONDS := 3.0
const FLAP_BOB := 3.0

var building: Building
var wildlife: WildlifeView
var _column := 0
## How high the foot of the nest is above the point in front of the house, as the roof is shown now.
var _roof_lift := 0.0
var _nest: Sprite2D
var _chicks: Array[Chick] = []
var _parents: Array[Stork] = []
var _young := 0
var _is_young_grown := false


## One young of the nest: its picture and what it does on the rim.
class Chick:
	var sprite: Sprite2D
	var seconds_left := 0.0
	var is_flapping := false
	var seconds := 0.0


func _ready() -> void:
	_column = wildlife.nests.column(building)
	position = wildlife.in_front_of(building, _column)
	for slot in CHICK_MOST:
		var chick := Chick.new()
		chick.sprite = WildlifeSprites.make_sprite(&"stork_chick")
		chick.sprite.flip_h = slot % 2 == 1
		chick.sprite.hide()
		# So that the young of a nest do not all flap together.
		chick.seconds_left = wildlife.rng.randf_range(0.0, STAND_SECONDS.y)
		add_child(chick.sprite)
		_chicks.append(chick)
	# The nest over the lower part of the young, so that they come up out of it.
	_nest = WildlifeSprites.make_sprite(&"stork_nest")
	add_child(_nest)
	add_to_group(ArtSet.VIEWS)
	_show_nest_lift()


func _process(delta: float) -> void:
	for chick in _chicks:
		if chick.sprite.visible and _is_young_grown:
			_move_grown_chick(chick, delta)


func show_art_set() -> void:
	_nest.texture = WildlifeSprites.sheet_texture(&"stork_nest")
	for chick in _chicks:
		chick.sprite.texture = WildlifeSprites.sheet_texture(&"stork_chick")


## Looks at who is in the nest now: shows the young, and sends parents off or in so that as many
## as should be at home are. At once (`is_instant`) the pair is on the nest, not flying in or off.
func update(is_instant := false) -> void:
	var occupants := wildlife.occupants_of(building)
	_show_young(occupants, is_instant)
	_show_nest_lift()
	_parents = _parents.filter(
		func(parent: Stork) -> bool: return is_instance_valid(parent) and not parent.is_done
	)
	while _parents.size() > occupants.parents_home:
		_parents.pop_back().dismiss()
	while _parents.size() < occupants.parents_home:
		_add_parent(_parents.size(), is_instant)


## Takes the pair off the nest and puts it as it should be, at once (time has skipped).
func settle() -> void:
	for parent in _parents:
		parent.is_done = true
	_parents.clear()
	update(true)


## The nest, and the young on it, are lifted to the roof as it is shown now (it is higher under
## snow).
func _show_nest_lift() -> void:
	_roof_lift = wildlife.roof_lift(building, _column)
	_nest.position.y = -_roof_lift
	if not _is_young_grown:
		for chick in _chicks:
			chick.sprite.position.y = -_roof_lift


func _show_young(occupants: StorkNests.Occupants, is_instant: bool) -> void:
	var is_grown := occupants.stage == StorkNests.Stage.FLEDGING
	if not is_instant and occupants.young < _young and is_grown:
		for _gone in _young - occupants.young:
			_send_young_off()
	_young = occupants.young
	_is_young_grown = is_grown
	var look := &"head_small"
	if is_grown:
		look = &"stand"
	elif occupants.growth >= GROWN_FROM:
		look = &"head_grown"
	elif occupants.growth >= HALF_GROWN_FROM:
		look = &"head_half_grown"
	for slot in CHICK_MOST:
		var chick := _chicks[slot]
		chick.sprite.visible = slot < _young
		chick.sprite.position.x = (slot - (_young - 1) / 2.0) * CHICK_SPACING
		chick.sprite.frame = WildlifeSprites.frame_index(&"stork_chick", look, 0)


## A young stork, grown, takes off from the rim and flies away.
func _send_young_off() -> void:
	var young := _new_stork()
	var column := _column + roundi(wildlife.rng.randf_range(-1.0, 1.0) * CHICK_SPACING)
	young.stand_on(building, column, wildlife.in_front_of(building, column))
	wildlife.add_stork(young)
	young.dismiss()


## What a grown young does on the rim: stands, looks round, and now and then flaps its wings,
## hopping a little.
func _move_grown_chick(chick: Chick, delta: float) -> void:
	chick.seconds += delta
	chick.seconds_left -= delta
	if chick.seconds_left <= 0.0:
		chick.is_flapping = not chick.is_flapping
		chick.seconds = 0.0
		chick.seconds_left = wildlife.rng.randf_range(
			FLAP_SECONDS.x if chick.is_flapping else STAND_SECONDS.x,
			FLAP_SECONDS.y if chick.is_flapping else STAND_SECONDS.y
		)
	var action := &"flap" if chick.is_flapping else &"stand"
	var step := int(chick.seconds * FLAP_FRAMES_PER_SECOND)
	var look_round := int(chick.seconds / LOOK_ROUND_SECONDS) % 2
	var column: int = BEAT_FRAMES[step % BEAT_FRAMES.size()] if chick.is_flapping else look_round
	chick.sprite.frame = WildlifeSprites.frame_index(&"stork_chick", action, column)
	var bob := absf(sin(chick.seconds * TAU)) * FLAP_BOB if chick.is_flapping else 0.0
	chick.sprite.position.y = -(_roof_lift + RIM_HEIGHT + bob)


func _add_parent(number: int, is_instant: bool) -> void:
	var column := _column + (number * 2 - 1) * PARENT_SPACING
	var ground := wildlife.in_front_of(building, column)
	var stork := _new_stork()
	if is_instant:
		stork.stand_on(building, column, ground)
	else:
		stork.position = wildlife.arrival_point(building)
		stork.fly_to(building, column, ground)
	wildlife.add_stork(stork)
	_parents.append(stork)


## A stork of this nest, standing as high as its rim.
func _new_stork() -> Stork:
	var stork := Stork.new(WildlifeRules.ROOF_STORK)
	stork.is_nest_parent = true
	stork.nest_lift = RIM_HEIGHT
	return stork
