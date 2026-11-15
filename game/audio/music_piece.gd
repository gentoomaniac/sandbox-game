class_name MusicPiece
extends RefCounted
## A piece of assets/music/: its module (<name>.mod) and what tools/music/generate.py wrote beside
## it in <name>.cfg: the speed and tempo, the rows in a beat and the beats in a bar, and its
## sections. Plain data; ModuleRenderer renders it and MusicPlayer plays it.
##
## A piece may have a fuller version (#15), <name>_full.mod: the chiptune plays with the classic
## 16 px art, the fuller one with the 32 px art. The generator gives it the piece's time and
## sections, so it plays the same parts and switches with the chiptune in step.

## What a fuller version's file name ends in, before the extension.
const FULL_SUFFIX := "_full"


## A stretch of the piece that plays on its own: it starts from the same state wherever it is
## entered (the piece's speed and tempo, every channel silent), so it can follow any of the
## sections that name it among their exits, and a piece can start with it.
class Section:
	var name := ""
	## Its first pattern's place in the module's order list.
	var order := 0
	var rows := 0
	## The sections that may follow it at its end, itself among them when it loops.
	var exits: Array[String] = []

	## What ModuleRenderer renders to play the section from its start to its end.
	func part() -> Vector2i:
		return Vector2i(order, rows)


var name := ""
## The chiptune.
var module: TrackerModule
## The fuller version, or null where the piece has none.
var full_module: TrackerModule
var speed := 6
var tempo := 125
var beat_rows := 4
var bar_beats := 4
## In the order of the piece: the first is the one that loops when nothing else is asked.
var sections: Array[Section] = []


## The piece called `piece_name` in `directory`, with its fuller version where it has one; null,
## with an error, when its files are missing or wrong.
static func read(directory: String, piece_name: String) -> MusicPiece:
	var base := directory.path_join(piece_name)
	var bytes := FileAccess.get_file_as_bytes(base + ".mod")
	var file := ConfigFile.new()
	var problem := ""
	var piece := MusicPiece.new()
	piece.name = piece_name
	piece.module = TrackerModule.from_bytes(bytes)
	var full_path := base + FULL_SUFFIX + ".mod"
	if FileAccess.file_exists(full_path):
		piece.full_module = TrackerModule.from_bytes(FileAccess.get_file_as_bytes(full_path))
	if piece.module == null:
		problem = "%s.mod is no module the renderer plays" % piece_name
	elif FileAccess.file_exists(full_path) and piece.full_module == null:
		problem = "%s%s.mod is no module the renderer plays" % [piece_name, FULL_SUFFIX]
	elif piece.full_module != null and piece.full_module.order != piece.module.order:
		problem = "%s%s.mod has another order list" % [piece_name, FULL_SUFFIX]
	elif file.load(base + ".cfg") != OK:
		problem = "%s.cfg can't be read" % piece_name
	else:
		problem = piece._read_sections(file)
	if problem != "":
		push_error("MusicPiece: %s" % problem)
		return null
	return piece


## The module of the fuller version when `is_full` and the piece has one, else the chiptune's.
func module_of(is_full: bool) -> TrackerModule:
	return full_module if is_full and full_module != null else module


## The section the piece loops: its first.
func loop_section() -> Section:
	return sections[0]


## What ModuleRenderer renders to play `form`, the sections named one after the other (and round
## to the first again); an empty form is the first section alone. See `form_problem` first.
func parts(form: Array[String]) -> Array[Vector2i]:
	var played: Array[Vector2i] = []
	if form.is_empty():
		played.append(loop_section().part())
	for section_name in form:
		played.append(section_named(section_name).part())
	return played


## What is wrong with `form` (see `parts`): a section it names that the piece hasn't, or a section
## followed by one it doesn't exit to (its last by its first, as the form goes round); "" for
## nothing.
func form_problem(form: Array[String]) -> String:
	for section_name in form:
		if section_named(section_name) == null:
			return "%s has no section %s" % [name, section_name]
	for index in form.size():
		var section := section_named(form[index])
		var after := form[(index + 1) % form.size()]
		if not section.exits.has(after):
			return "%s: section %s doesn't exit to %s" % [name, section.name, after]
	return ""


## The section called `section_name`, or null.
func section_named(section_name: String) -> Section:
	for section in sections:
		if section.name == section_name:
			return section
	return null


## Reads the sections file; returns what is wrong with it, or "".
func _read_sections(file: ConfigFile) -> String:
	for key in ["speed", "tempo", "beat_rows", "bar_beats"]:
		if not file.has_section_key("piece", key):
			return "%s.cfg has no [piece] %s" % [name, key]
	speed = file.get_value("piece", "speed")
	tempo = file.get_value("piece", "tempo")
	beat_rows = file.get_value("piece", "beat_rows")
	bar_beats = file.get_value("piece", "bar_beats")
	for section_name in file.get_sections():
		if section_name == "piece":
			continue
		var section := Section.new()
		section.name = section_name
		section.order = file.get_value(section_name, "order", -1)
		section.rows = file.get_value(section_name, "rows", 0)
		section.exits.assign(file.get_value(section_name, "exits", []))
		if section.order < 0 or section.order >= module.order.size() or section.rows < 1:
			return "%s.cfg: section %s is outside the module" % [name, section_name]
		sections.append(section)
	if sections.is_empty():
		return "%s.cfg has no sections" % name
	for section in sections:
		for exit_name in section.exits:
			if section_named(exit_name) == null:
				return (
					"%s.cfg: section %s exits to %s, which is none"
					% [name, section.name, exit_name]
				)
	return ""
