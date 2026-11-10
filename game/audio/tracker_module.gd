class_name TrackerModule
extends RefCounted
## A 4-channel ProTracker module ("M.K."), as tools/music/generate.py writes them: its samples,
## order list and patterns, read from the file's bytes. ModuleRenderer plays it. A trial of task
## 169, not used by the game yet.

const CHANNELS := 4
const PATTERN_ROWS := 64
const SAMPLE_SLOTS := 31
## The bytes of a cell, and so the ints of a cell in `patterns`: period, sample, effect, parameter.
const CELL_SIZE := 4
const HEADER_SIZE := 20 + SAMPLE_SLOTS * 30
const PATTERNS_START := HEADER_SIZE + 2 + 128 + 4
## The periods of the highest and lowest of ProTracker's notes, B-3 and C-1 (finetune 0); a note
## outside them is refused (the vibrato may still swing a little beyond).
const LOWEST_PERIOD := 113
const HIGHEST_PERIOD := 856


## A sample: its 8-bit data as -1..1, and its loop (a length of 0 is a one-shot).
class Sample:
	var data := PackedFloat32Array()
	var loop_start := 0
	var loop_length := 0
	## 0..64
	var volume := 0


var samples: Array[Sample] = []
## The patterns to play, in order.
var order := PackedInt32Array()
## Per pattern, its cells row by row and channel by channel, CELL_SIZE ints each.
var patterns: Array[PackedInt32Array] = []


## The module in `bytes`, or null when `refusal_of` finds something wrong with them.
static func from_bytes(bytes: PackedByteArray) -> TrackerModule:
	var module := TrackerModule.new()
	return module if module._read(bytes) == "" else null


## Why `bytes` are refused, or "" when they are a module ModuleRenderer can play: a 4-channel "M.K."
## module, whole (every pattern the order list names and every sample there), with an order list
## of 1 to 128 patterns, samples of finetune 0 whose loops lie within them, and only the effects
## ModuleRenderer plays, without ProTracker's effect memory (see tools/music/generate.py), pattern
## breaks to rows 0 to 63 included, samples 1 to 31 and notes from C-1 to B-3.
static func refusal_of(bytes: PackedByteArray) -> String:
	return TrackerModule.new()._read(bytes)


## Reads `bytes` into this module; returns why they are refused, or "".
func _read(bytes: PackedByteArray) -> String:
	var problem := _read_order(bytes)
	if problem == "":
		problem = _read_samples(bytes)
	if problem == "":
		problem = _read_patterns(bytes)
	return problem


func _read_order(bytes: PackedByteArray) -> String:
	if bytes.size() < PATTERNS_START:
		return "too short for a module header"
	if bytes.slice(PATTERNS_START - 4, PATTERNS_START).get_string_from_ascii() != "M.K.":
		return "no M.K. module"
	var order_length := bytes[HEADER_SIZE]
	if order_length < 1 or order_length > 128:
		return "an order list of %d patterns" % order_length
	for index in order_length:
		var pattern := bytes[HEADER_SIZE + 2 + index]
		if pattern >= 128:
			return "pattern %d in the order list" % pattern
		order.append(pattern)
	if _samples_start(_pattern_count()) > bytes.size():
		return "cut off in the patterns"
	return ""


func _read_samples(bytes: PackedByteArray) -> String:
	var sample_start := _samples_start(_pattern_count())
	for slot in SAMPLE_SLOTS:
		var header := 20 + slot * 30
		var sample := Sample.new()
		var length := _word(bytes, header + 22) * 2
		if bytes[header + 24] & 0x0F != 0:
			return "sample %d has a finetune" % (slot + 1)
		sample.volume = mini(bytes[header + 25], 64)
		var loop_length := _word(bytes, header + 28) * 2
		if loop_length > 2:
			sample.loop_start = _word(bytes, header + 26) * 2
			sample.loop_length = loop_length
			if sample.loop_start + loop_length > length:
				return "the loop of sample %d goes past its end" % (slot + 1)
		if sample_start + length > bytes.size():
			return "cut off in sample %d" % (slot + 1)
		sample.data.resize(length)
		for index in length:
			sample.data[index] = bytes.decode_s8(sample_start + index) / 128.0
		sample_start += length
		samples.append(sample)
	return ""


func _read_patterns(bytes: PackedByteArray) -> String:
	var pattern_size := PATTERN_ROWS * CHANNELS * CELL_SIZE
	for pattern in _pattern_count():
		var cells := PackedInt32Array()
		cells.resize(PATTERN_ROWS * CHANNELS * CELL_SIZE)
		var start := PATTERNS_START + pattern * pattern_size
		for cell in PATTERN_ROWS * CHANNELS:
			var at := start + cell * CELL_SIZE
			var effect := bytes[at + 2] & 0x0F
			var parameter := bytes[at + 3]
			var period := (bytes[at] & 0x0F) << 8 | bytes[at + 1]
			var sample := (bytes[at] & 0xF0) | bytes[at + 2] >> 4
			var place := "in pattern %d, row %d" % [pattern, cell / CHANNELS]
			if not _is_played(effect, parameter):
				return "effect %X%02X %s" % [effect, parameter, place]
			if sample > SAMPLE_SLOTS:
				return "sample %d %s" % [sample, place]
			if period != 0 and (period < LOWEST_PERIOD or period > HIGHEST_PERIOD):
				return "period %d %s" % [period, place]
			cells[cell * CELL_SIZE] = period
			cells[cell * CELL_SIZE + 1] = sample
			cells[cell * CELL_SIZE + 2] = effect
			cells[cell * CELL_SIZE + 3] = parameter
		patterns.append(cells)
	return ""


## The patterns stored: as many as the highest the order list names, and those below it.
func _pattern_count() -> int:
	return Array(order).max() + 1


static func _samples_start(pattern_count: int) -> int:
	return PATTERNS_START + pattern_count * PATTERN_ROWS * CHANNELS * CELL_SIZE


## Whether ModuleRenderer plays an effect as ProTracker does: the effect set of the generator.
static func _is_played(effect: int, parameter: int) -> bool:
	var x := parameter >> 4
	var y := parameter & 0x0F
	match effect:
		0x0, 0x1, 0x2:
			return true
		0x3:
			return parameter > 0
		0x4:
			return x > 0 and y > 0
		0xA:
			return x == 0 or y == 0
		0xC:
			return parameter <= 64
		0xD:
			return x <= 9 and y <= 9 and x * 10 + y < PATTERN_ROWS
		0xE:
			return x == 0xC
		0xF:
			return parameter > 0
	return false


## A big-endian 16-bit word, as the Amiga wrote them.
static func _word(bytes: PackedByteArray, at: int) -> int:
	return bytes[at] << 8 | bytes[at + 1]
