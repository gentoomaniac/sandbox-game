class_name MusicPiece
extends RefCounted
## A piece of assets/music/: its module (<name>.mod) and what tools/music/generate.py wrote beside
## it in <name>.cfg: the speed and tempo, the rows in a beat and the beats in a bar, and its
## sections. Plain data; ModuleRenderer renders it and MusicPlayer plays it.


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
var module: TrackerModule
var speed := 6
var tempo := 125
var beat_rows := 4
var bar_beats := 4
## In the order of the piece: the first is the one that loops when nothing else is asked.
var sections: Array[Section] = []


## The piece called `piece_name` in `directory`; null, with an error, when its files are missing
## or wrong.
static func read(directory: String, piece_name: String) -> MusicPiece:
	var base := directory.path_join(piece_name)
	var bytes := FileAccess.get_file_as_bytes(base + ".mod")
	var file := ConfigFile.new()
	var problem := ""
	var piece := MusicPiece.new()
	piece.name = piece_name
	piece.module = TrackerModule.from_bytes(bytes)
	if piece.module == null:
		problem = "%s.mod is no module the renderer plays" % piece_name
	elif file.load(base + ".cfg") != OK:
		problem = "%s.cfg can't be read" % piece_name
	else:
		problem = piece._read_sections(file)
	if problem != "":
		push_error("MusicPiece: %s" % problem)
		return null
	return piece


## The section the piece loops: its first.
func loop_section() -> Section:
	return sections[0]


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
