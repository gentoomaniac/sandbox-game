class_name StartupOptions
extends RefCounted
## The flags after `--` on the Godot command line, parsed once into typed fields. Each field is
## its flag in snake_case (`--chest-inside` is `chest_inside`); a field keeps its default when
## its flag is not given. An unknown flag is a warning, a malformed value an error.
## Pass them to `make screenshot` with `ARGS="--weather=rain --day=45"`.
##
## A `<x>,<y>` is a tile of the world (whole numbers); a tile flag left out is `NO_TILE`.
##
## Which game is run
##   --new-game               ignore the save
##   --save-path=<file>       use another save file (keeps tests and screenshots off yours)
##   --settings-path=<file>   use another settings file
##   --mute                   silence all sound (events still play and log)
##   --background             make the window unfocusable, so it takes no focus but no keyboard
##                            input either: not for playing. `make screenshot` passes both.
##   --sound-log              print every sound event as it plays (see AudioService)
##
## The screenshot
##   --screenshot=<path>      save one frame as PNG once streaming has settled, then quit
##   --screenshot-size=<w>x<h>  make the picture exactly that size, showing what a window of that
##                            size shows, whatever size the window manager gives the window
##   --screenshot-delay=<s>   wait that many real seconds more, with the clock running (to see
##                            what a midnight changes: `--day=30 --time=23:50
##                            --screenshot-delay=10`)
##   --menu=<page>            open that menu page (pause, settings, controls, display, game,
##                            audio, language_model); with --screenshot the shot is of the menu
##   --tooltip=<id>           show the tooltip of a control as if the mouse rested on it:
##                            hotbar_<0..7>; inventory_<8..27> and equipment_<slot> (with
##                            --inventory); recipe_<id> (with --crafting); inventory_<8..27>
##                            and chest_<n> (with --storage); setting_ui_scale and
##                            setting_day_length (with --menu=game); setting_master_volume,
##                            setting_effects_volume, setting_ambience_volume and
##                            setting_sound_in_background (with --menu=audio);
##                            action_<action> (with --menu=controls)
##
## Where and when
##   --at=<x>,<y>             put the player on that tile instead of at the camp
##   --day=<n>                the day number (days 1, 31, 61 and 91 start a season)
##   --time=<hh:mm>           the time of day
##   --weather=<condition>    force the weather (clear, rain, snow, fog, wind, storm, thunder)
##   --flash                  keep the flash of lightning on
##   --snow=<0..1>            force the snow cover
##   --zoom=<z>               the camera zoom
##   --camera-shift=<x>,<y>   move the camera by that many art pixels, fractions included (to
##                            check smooth scrolling)
##   --coordinates            show the coordinates (F3)
##   --classic-art            show the classic art (see ArtSet), not saved in the settings
##   --mouse-tile=<x>,<y>     pretend the mouse is always on that tile
##
## The player
##   --energy=<0..100>        start with that much energy; 0 passes out at start
##   --health=<0..100>        start with that much health
##   --hold=<item>            put 5 of an item in the inventory and hold it
##   --wear=<item>            put a wearable item on (straw_hat, shirt, ...)
##   --hair=<n>               the hair style (F6 cycles it)
##   --pose=<direction>[,<column>]  face that way, optionally frozen on that walking frame (on
##                            horseback a column of the ridden horse: 0 standing, 1 to 4
##                            walking, 5 to 8 trotting)
##   --riding=<look>          sit on a saddled horse of that look (bay, black, grey, pony)
##   --inside[=<building>]    walk into the first house as soon as one exists (see --house), or
##                            into the first building of that type (see --street)
##   --sleep                  go to bed as soon as the world is drawn (a new game starts beside
##                            the sleeping bag; with --inside, in the room's first bed). With
##                            --time=00:59 and a --screenshot-delay of a second or more the
##                            player stays up too late instead.
##
## Screens and the console
##   --inventory              open the character screen at start
##   --skills                 open the character screen at start, on the skills tab
##   --crafting               open the crafting menu at start
##   --station                open the crafting menu of the nearest station in reach, once the
##                            map is drawn (with --inside, in the house)
##   --storage                open the storage screen of the --chest or --chest-inside chest
##   --console=<line>;<line>  run those console commands at start and leave the console open
##   --chat=<line>;<line>     speak to the nearest villager once the world is drawn (see
##                            --npcs, --villager) and say those lines, each after the answer to
##                            the last
##   --chat-script=<line>;<line>  speak to the nearest villager as with --chat, but the lines
##                            are already in the chat, said by you and the villager in turn
##                            (you first), a minute apart: no language model asked. A last
##                            line of `...` leaves the villager typing.
##
## Building
##   --building=<id>[.<style>]  the building the hammer places, in its own look or a style
##                            (kate.brick)
##   --ghost=<x>,<y>          hold the hammer, its ghost pinned on that tile (see BuildMode)
##   --taking-down            with --ghost: the hammer takes down instead of building
##   --house=<x>,<y>          place the chosen building there once its chunks are loaded
##
## Things put in the world (see the Debug* classes)
##   --field=<x>,<y>          a small tilled field with crops in every growth stage
##   --drops=<x>,<y>          what a felled tree, a mined stone, a harvested crop and a picked
##                            bush drop
##   --forage=<x>,<y>         a stump, bushes and a sapling in a row, and some of every new item
##   --items=<x>,<y>          one of every item on the ground, ten to a row, and in the inventory
##                            as many as fit (see DebugItems)
##   --churchyard=<x>,<y>     the church, its bell frame and graves in a walled churchyard
##   --street=<x>,<y>         every building in a row, from that tile eastwards (see DebugStreet)
##   --felled=<x>,<y>         trees felled from each side, with stumps, trunks and tree seeds
##   --mow=<x>,<y>            mows twice with the scythe from that tile (--day=45 for summer)
##   --path=<x>,<y>           a desire path walked from that tile eastwards (see DebugPath)
##   --path-days=<walked>,<left>  the days --path is walked and then left to grow back
##                            (default 6,0)
##   --worn-ground=<x>,<y>    a yard worn by many feet from that tile: a path, a trodden rim, a
##                            few worn islands (see DebugWornGround)
##   --chest=<x>,<y>          a chest with some items on that tile
##   --chest-inside=<x>,<y>   a chest on that tile of the first house's room (with --inside)
##   --landing=<x>,<y>        the fisherman's landing: a jetty from that tile west over the water,
##                            a rowing boat, a net frame and eel traps (with --building=fisher_hut
##                            and --house for the hut)
##   --yard=<x>,<y>           the chest and the stations in a row from that tile eastwards, and
##                            behind them a Knick, a wattle fence, a fieldstone wall and a dyke on
##                            the slant (see DebugYard)
##
## Done once the world is drawn (see DebugRunner)
##   --harvest=<x>,<y>        fell two oaks, cut a trunk, break a stone and mow a patch in a row
##                            from that tile, to catch the falling trees and the hopping items
##                            (use --day=45, --screenshot-delay=0.3 and --at= ten tiles right)
##   --hit=<x>,<y>            hit the object on that tile once, without damage (its shake, what
##                            flies off; the sweat of a tired player, so add --energy=15). The
##                            particles last about a second: use a short --screenshot-delay.
##   --wildlife=<kind>[,<kind>]  put a few animals of those kinds near the player and leave it at
##                            that (bird, rabbit, squirrel, deer, bee, butterfly, flock, stork,
##                            firefly: shines only at night, so add --day=45 --time=22:00;
##                            roof_stork: on the roof of the nearest house, see --house; geese,
##                            flying_geese: one flock of them; mouse, frog; on the coast
##                            oystercatcher, dunlin: one flock of them; gull, tern)
##   --wildlife-calm          the animals take no notice of the player
##   --livestock=<species>[,<species>]  put a few farm animals of those species near the player
##                            (cow, sheep, chicken, rabbit, dog, cat, horse; pony: horses of
##                            that look)
##   --hunt                   put a cat of each look a little right of the player, each with a
##                            mouse further right that it hunts at once: it crouches for 1.5 s,
##                            creeps up for a few seconds and pounces (use --screenshot-delay)
##   --npcs=<count>           put that many villagers near the player, the same ones every time
##   --villager=<id>          put the villager of data/villagers.cfg with that id near the player
##   --switch-art             with --screenshot: press the key that switches the art (F7) when
##                            the shot would be taken, and take it a few frames later, to see
##                            the switch in a running game. The switch is saved in the
##                            settings: give it a --settings-path of its own.

## The value of a tile flag that was not given.
const NO_TILE := Vector2i(1 << 30, 1 << 30)

# Which game is run
var new_game := false
var save_path := SaveFile.DEFAULT_PATH
var settings_path := GameSettings.DEFAULT_PATH
var mute := false
var background := false
var sound_log := false

# The screenshot
var screenshot := ""
var screenshot_delay := 0.0
## Zero when the picture is the window as it is.
var screenshot_size := Vector2i.ZERO
## A `PauseMenu.Page`, or -1 for none.
var menu := -1
var tooltip := ""

# Where and when
var at := NO_TILE
## 0 for the day of the game, which the clock would never have.
var day := 0
## -1 for the time of the game.
var time_hour := -1
var time_minute := 0
var weather := &""
var flash := false
## -1 for the snow cover of the game.
var snow := -1.0
## The camera starts zoomed out as far as it goes, where the player keeps it.
var zoom := ViewMath.MIN_ZOOM
var camera_shift := Vector2.ZERO
var coordinates := false
var classic_art := false
var mouse_tile := NO_TILE

# The player
## -1 for the energy and the health of the game.
var energy := -1.0
var health := -1.0
var hold := &""
var wear := &""
## -1 for the hair of the game.
var hair := -1
var pose := ""
## -1 for a walking player.
var pose_column := -1
var riding := &""
var inside := false
## The building type `--inside` walks into, or empty for the first house.
var inside_building := &""
var sleep := false

# Screens and the console
var inventory := false
var skills := false
var crafting := false
var station := false
var storage := false
var console := PackedStringArray()
var chat := PackedStringArray()
var chat_script := PackedStringArray()

# Building
var building := &""
## The style of `building`, &"" for its own look.
var building_style := &""
var ghost := NO_TILE
var taking_down := false
var house := NO_TILE

# Things put in the world
var field := NO_TILE
var drops := NO_TILE
var forage := NO_TILE
var items := NO_TILE
var churchyard := NO_TILE
var street := NO_TILE
var felled := NO_TILE
var mow := NO_TILE
var path := NO_TILE
var path_days := Vector2i(6, 0)
var worn_ground := NO_TILE
var chest := NO_TILE
var chest_inside := NO_TILE
var landing := NO_TILE
var yard := NO_TILE

# Done once the world is drawn
var harvest := NO_TILE
var hit := NO_TILE
var wildlife := PackedStringArray()
var wildlife_calm := false
var livestock := PackedStringArray()
var hunt := false
var npcs := 0
var villager := ""
var switch_art := false


static func from_command_line() -> StartupOptions:
	return StartupOptions.new(OS.get_cmdline_user_args())


## The options that only show the game differently, for the game that F8 loads: the paths, sound,
## zoom, the coordinates and the art. What changes the game or opens a window is left out.
func kept_for_quick_load() -> StartupOptions:
	var kept := StartupOptions.new()
	for name in [
		"save_path",
		"settings_path",
		"mute",
		"background",
		"sound_log",
		"zoom",
		"camera_shift",
		"coordinates",
		"classic_art"
	]:
		kept.set(name, get(name))
	return kept


func _init(args := PackedStringArray()) -> void:
	for arg in args:
		var name := arg.get_slice("=", 0)
		match name:
			"--new-game":
				new_game = true
			"--save-path":
				save_path = _value(arg)
			"--settings-path":
				settings_path = _value(arg)
			"--mute":
				mute = true
			"--background":
				background = true
			"--sound-log":
				sound_log = true
			"--screenshot":
				screenshot = _value(arg)
			"--screenshot-size":
				screenshot_size = _size(arg)
			"--screenshot-delay":
				screenshot_delay = float(_value(arg))
			"--menu":
				menu = PauseMenu.Page.get(_value(arg).to_upper(), -1)
			"--tooltip":
				tooltip = _value(arg)
			"--at":
				at = _tile(arg)
			"--day":
				day = maxi(int(_value(arg)), 1)
			"--time":
				_parse_time(arg)
			"--weather":
				weather = StringName(_value(arg))
			"--flash":
				flash = true
			"--snow":
				snow = float(_value(arg))
			"--zoom":
				zoom = float(_value(arg))
			"--camera-shift":
				var shift := _value(arg).split_floats(",")
				camera_shift = Vector2(shift[0], shift[1])
			"--coordinates":
				coordinates = true
			"--classic-art":
				classic_art = true
			"--switch-art":
				switch_art = true
			"--mouse-tile":
				mouse_tile = _tile(arg)
			"--energy":
				energy = float(_value(arg))
			"--health":
				health = float(_value(arg))
			"--hold":
				hold = StringName(_value(arg))
			"--wear":
				wear = StringName(_value(arg))
			"--hair":
				hair = int(_value(arg))
			"--pose":
				var parts := _value(arg).split(",")
				pose = parts[0]
				if parts.size() > 1:
					pose_column = int(parts[1])
			"--riding":
				riding = StringName(_value(arg))
			"--inside":
				inside = true
				if "=" in arg:
					inside_building = StringName(_value(arg))
			"--sleep":
				sleep = true
			"--inventory":
				inventory = true
			"--skills":
				skills = true
			"--crafting":
				crafting = true
			"--station":
				station = true
			"--storage":
				storage = true
			"--console":
				console = _value(arg).split(";")
			"--chat":
				chat = _value(arg).split(";")
			"--chat-script":
				chat_script = _value(arg).split(";")
			"--building":
				var parts := _value(arg).split(BuildingRules.STYLE_SEPARATOR)
				building = StringName(parts[0])
				building_style = StringName(parts[1]) if parts.size() > 1 else &""
			"--ghost":
				ghost = _tile(arg)
			"--taking-down":
				taking_down = true
			"--house":
				house = _tile(arg)
			"--field":
				field = _tile(arg)
			"--drops":
				drops = _tile(arg)
			"--forage":
				forage = _tile(arg)
			"--items":
				items = _tile(arg)
			"--churchyard":
				churchyard = _tile(arg)
			"--street":
				street = _tile(arg)
			"--felled":
				felled = _tile(arg)
			"--mow":
				mow = _tile(arg)
			"--path":
				path = _tile(arg)
			"--path-days":
				var days := _tile(arg)
				if days != NO_TILE:
					path_days = days
			"--worn-ground":
				worn_ground = _tile(arg)
			"--chest":
				chest = _tile(arg)
			"--chest-inside":
				chest_inside = _tile(arg)
			"--landing":
				landing = _tile(arg)
			"--yard":
				yard = _tile(arg)
			"--harvest":
				harvest = _tile(arg)
			"--hit":
				hit = _tile(arg)
			"--wildlife":
				wildlife = _value(arg).split(",")
			"--wildlife-calm":
				wildlife_calm = true
			"--livestock":
				livestock = _value(arg).split(",")
			"--hunt":
				hunt = true
			"--npcs":
				npcs = _value(arg).to_int()
			"--villager":
				villager = _value(arg)
			_:
				if arg.begins_with("--"):
					push_warning("Unknown flag '%s' (see StartupOptions)" % arg)


## What follows the first `=` of a `--flag=value` argument.
func _value(arg: String) -> String:
	return arg.substr(arg.find("=") + 1)


## The tile of a `--flag=<x>,<y>` argument, or NO_TILE (after an error) if it is malformed.
func _tile(arg: String) -> Vector2i:
	var parts := _value(arg).split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("%s expects <x>,<y>, got '%s'" % [arg.get_slice("=", 0), _value(arg)])
		return NO_TILE
	return Vector2i(int(parts[0]), int(parts[1]))


func _size(arg: String) -> Vector2i:
	var parts := _value(arg).split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("%s expects <w>x<h>, got '%s'" % [arg.get_slice("=", 0), _value(arg)])
		return Vector2i.ZERO
	return Vector2i(maxi(int(parts[0]), 1), maxi(int(parts[1]), 1))


func _parse_time(arg: String) -> void:
	var text := _value(arg)
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_error("--time expects hh:mm, got '%s'" % text)
		return
	var hour := int(parts[0])
	var minute := int(parts[1])
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		push_error("--time out of range: '%s'" % text)
		return
	time_hour = hour
	time_minute = minute
