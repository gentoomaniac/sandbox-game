class_name TirednessView
extends Node2D
## The signs that the player is tired (see TirednessSigns): the thought bubble over the head
## and the sweat that flies off it. A child of the PlayerView, so it follows the player.

## Where the head is, relative to the feet, in pixels: the top of the hair's outline in the
## character sheets (row 6 of 64), and the top of a hat's (row 1; all hats are as tall). The
## bubble's tail points at it from four pixels above; the sweat starts at the side of the head.
const BARE_HEAD_TOP := -58
const HAT_TOP := -63
const BUBBLE_GAP := 4
const SWEAT_ORIGIN := Vector2(0, -48)
## Above the player's layers and the things in front of them.
const DRAW_ORDER := 100

## Whether the player is up and about: false while asleep or fading through a sleep or a
## collapse, when the late warning must stay quiet.
var is_awake := true

var _player: PlayerState
var _clock: GameClock
var _signs: TirednessSigns
var _bubble := ThoughtBubble.new()
var _sweat := HitParticles.new()


func _init() -> void:
	z_index = DRAW_ORDER
	add_child(_bubble)
	add_child(_sweat)


## Where the bubble's bottom centre (the tip of its tail) is, for a player who looks like this.
static func bubble_origin(appearance: Appearance) -> Vector2:
	var is_hat_worn := appearance.layers.any(
		func(layer: Dictionary) -> bool: return layer.slot == Appearance.HEAD
	)
	return Vector2(0, (HAT_TOP if is_hat_worn else BARE_HEAD_TOP) - BUBBLE_GAP)


func watch(player: PlayerState, clock: GameClock, rules: EnergyRules) -> void:
	_player = player
	_clock = clock
	_signs = TirednessSigns.new(rules)


## The player has just done `use`, which may have cost energy.
func acted(use: ToolUse.Use) -> void:
	_sweat.emit(_signs.sweat_for(use, _player.energy), SWEAT_ORIGIN)


func _process(_delta: float) -> void:
	_bubble.position = bubble_origin(_player.appearance)
	var clock_minute := (_clock.day - 1) * GameClock.MINUTES_PER_DAY + _clock.minute_of_day
	var icon := _signs.late_bubble_for(clock_minute, is_awake)
	if icon != &"":
		_bubble.show_icon(icon)
