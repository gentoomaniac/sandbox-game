class_name ToolSwingRules
extends RefCounted
## How a tool is swung, read from data/tool_swing.cfg (see there for what each number means): the
## motion of each kind of tool, the time each frame of it shows and the frame where the blow lands.
## The frames of all motions follow each other in the columns of the swing sheets, in the order of
## the file. `from_file` reports every missing key, and `is_valid` says whether there was one.

const DEFAULT_PATH := "res://data/tool_swing.cfg"
const KEYS := ["tools", "frame_ms", "strike_frame"]

static var _default: ToolSwingRules

## {motion: {key: value}}, as in the file.
var _motions: Dictionary


func _init(motions: Dictionary) -> void:
	_motions = motions


## The rules of the data file, loaded the first time they are asked for.
static func default_rules() -> ToolSwingRules:
	if _default == null:
		_default = from_file(DEFAULT_PATH)
	return _default


static func from_file(path: String) -> ToolSwingRules:
	var rules := ToolSwingRules.new(DataFile.read_sections(path))
	for problem in rules.problems():
		push_error("%s: %s" % [path, problem])
	return rules


## What is missing or wrong, as "[motion] what".
func problems() -> Array[String]:
	var found: Array[String] = []
	if _motions.is_empty():
		found.append("no motions")
	for motion: String in _motions:
		var missing := KEYS.filter(func(key: String) -> bool: return not _motions[motion].has(key))
		for key: String in missing:
			found.append("[%s] no %s" % [motion, key])
		if (
			missing.is_empty()
			and strike_frame(StringName(motion)) >= frame_count(StringName(motion))
		):
			found.append("[%s] strike_frame is no frame of the swing" % motion)
	return found


func is_valid() -> bool:
	return problems().is_empty()


## The motion a kind of tool makes (see ItemTypes), or "" for one that is not swung.
func motion_of(tool_kind: StringName) -> StringName:
	for motion: String in _motions:
		if str(tool_kind) in _motions[motion]["tools"]:
			return StringName(motion)
	return &""


func frame_count(motion: StringName) -> int:
	return _motions[str(motion)]["frame_ms"].size()


## How many columns the swing sheets have: the frames of every motion.
func column_count() -> int:
	var columns := 0
	for motion: String in _motions:
		columns += frame_count(StringName(motion))
	return columns


## The column of a motion's first frame in the swing sheets.
func first_column(motion: StringName) -> int:
	var column := 0
	for other: String in _motions:
		if other == str(motion):
			return column
		column += frame_count(StringName(other))
	return -1


func strike_frame(motion: StringName) -> int:
	return _motions[str(motion)]["strike_frame"]


## Seconds from the start of the swing until `frame` begins.
func frame_start(motion: StringName, frame: int) -> float:
	var milliseconds := 0
	for index in frame:
		milliseconds += _motions[str(motion)]["frame_ms"][index]
	return milliseconds / 1000.0


## Seconds the whole swing lasts.
func duration(motion: StringName) -> float:
	return frame_start(motion, frame_count(motion))


## The frame of a motion shown `time` seconds into it (the last one for a time beyond its end).
func frame_at(motion: StringName, time: float) -> int:
	var frame := 0
	while frame + 1 < frame_count(motion) and time >= frame_start(motion, frame + 1):
		frame += 1
	return frame
