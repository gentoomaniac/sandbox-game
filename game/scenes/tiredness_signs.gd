class_name TirednessSigns
extends RefCounted
## What shows that the player is tired, decided from the energy alone (see EnergyRules
## `tired_level` and `exhausted_level`): sweat on every action while it is at or below one.
## A "zzz..." thought bubble warns of staying up too late, at the clock times of
## `late_warning_minutes`. The views draw it.

enum Level { RESTED, TIRED, EXHAUSTED }

## The longest time step, in game minutes, that counts as the clock running on. A bigger one
## is a jump (the `skip` command, a night's sleep) and warns of nothing it passes.
const MAX_CLOCK_STEP := 10
## The thought bubble icon (see ThoughtBubble) of the late warning.
const BUBBLE_ICON := &"zzz"

var _rules: EnergyRules
## The clock when `late_bubble_for` was last asked, in minutes since day 1 began; -1 if the
## player was not awake then.
var _last_minute := -1


func _init(rules: EnergyRules) -> void:
	_rules = rules


## The level this much energy is at.
func level_of(energy: float) -> Level:
	if energy <= _rules.exhausted_level():
		return Level.EXHAUSTED
	if energy <= _rules.tired_level():
		return Level.TIRED
	return Level.RESTED


## Takes note of the clock, at this many minutes since day 1 began; to be called every frame.
## Returns the icon of the thought bubble to show for staying up too late, if the clock has
## just run past a warning time, else an empty name. Nothing is shown while the player is not
## awake (asleep, collapsing), nor for warning times that a jump passes.
func late_bubble_for(clock_minute: int, is_awake: bool) -> StringName:
	var last_minute := _last_minute
	_last_minute = clock_minute if is_awake else -1
	if not is_awake or last_minute < 0 or clock_minute - last_minute > MAX_CLOCK_STEP:
		return &""
	for warning in _rules.late_warning_minutes():
		var days_before := floori(float(last_minute - warning) / GameClock.MINUTES_PER_DAY)
		var days_now := floori(float(clock_minute - warning) / GameClock.MINUTES_PER_DAY)
		if days_now > days_before:
			return BUBBLE_ICON
	return &""


## The sweat that an action throws at this much energy, as a HitEffect kind: only the uses
## that cost energy (see GameState `COST_KINDS`) make the player sweat.
func sweat_for(use: GameState.Use, energy: float) -> HitEffect.Kind:
	if not GameState.COST_KINDS.has(use):
		return HitEffect.Kind.NONE
	match level_of(energy):
		Level.EXHAUSTED:
			return HitEffect.Kind.SWEAT_HEAVY
		Level.TIRED:
			return HitEffect.Kind.SWEAT
	return HitEffect.Kind.NONE
