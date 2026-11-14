class_name LanternUpkeep
extends SimulationSystem
## Burns the candle of the player's lantern down while it shines (task 231): the burn is the
## candle's own state (see LanternCandle), so nothing here is kept. A candle that is burnt out is
## gone and the lantern goes out. Going to bed puts the lantern out first (GameState), so the
## candle does not burn through the night.

## Gives the player, who is a new one when a game is loaded.
var _player_of: Callable


func _init(player_of: Callable) -> void:
	_player_of = player_of


func advance(minutes: int, _clock: GameClock) -> void:
	var player: PlayerState = _player_of.call()
	if not player.is_lantern_shining():
		return
	var inventory := player.inventory
	if inventory.burn_candle(inventory.selected_slot, minutes):
		player.is_lantern_lit = false
