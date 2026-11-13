class_name ModuleRenderer
extends RefCounted
## Renders parts of a TrackerModule into an AudioStreamWAV (16 bit, mono or stereo), at once or on
## a WorkerThreadPool thread, where the stream is made whole, so the main thread only takes it. A
## prototype of task 169, kept apart from AudioService; MusicCrossfade plays it in the benchmark.
## The streams are plain AudioStreamWAVs: a script subclass that tells AudioStreamInteractive its
## beat (MusicStreamWAV) crashes the game's quit once played, so the beat is in `beat_seconds`.
##
## A part is Vector2i(order, rows): from row 0 of that place in the order list, that many rows,
## following the order list (a pattern break goes on to the next order, the end of the list back to
## its start). Parts play one after the other, the channels going on from one into the next, so
## [loop, loop] is how the loop sounds when it wraps. A render starts from the same state every
## time: ProTracker's default speed 6 and tempo 125, all channels silent; the generator starts every
## section with its own speed and tempo.
##
## A tick lasts mix_rate * 2.5 / tempo samples, cut to a whole number, as libmodplug does (the
## player tools/music/check.py compares with): at tempo 125 that is exact (20 ms), at other tempos a
## tick is up to a sample short, under 0.1 % at 22.05 kHz.
##
## It plays the effect set of tools/music/generate.py (0xy arpeggio, 1xx/2xx portamento, 3xx tone
## portamento, 4xy vibrato, Axy volume slide, Cxx volume, Dxx pattern break, ECx note cut, Fxx
## speed and tempo); TrackerModule refuses modules with others. Arpeggios step through ProTracker's
## period table as ProTracker does; the vibrato's sine is worked out where ProTracker looks it up
## in a table, which differs by a period step at most. Samples are interpolated linearly: the
## Amiga plays a looped wave exactly periodic, but taking the nearest sample at the mix rate moves
## the wave's steps by up to a frame, which put a 32-sample saw's sound only 22 dB above what it
## had off its harmonics (heard as a rough note that can't hold its pitch); interpolated, 47 dB.
## Volumes ramp, as in libmodplug: a channel's gain moves to a new volume over RAMP_SECONDS, and a
## struck note starts from silence while the note before fades out beside it, so a note change
## doesn't jump from wherever the old wave was (a click). In stereo the Amiga's channels 1 and 4
## are to the left and 2 and 3 to the right, each with a quarter of it on the other side, as hard
## Amiga panning tires on headphones.

## Half the Amiga's PAL clock: a sample plays at this many samples a second over its period.
const PAL_RATE := 3546894.6
## ProTracker's periods from C-1 to B-3 (finetune 0). An arpeggio finds the first of them at or
## below the note's period and steps up from there, so after a slide it lands on whole notes.
const PERIOD_TABLE := (
	"856 808 762 720 678 640 604 570 538 508 480 453 "
	+ "428 404 381 360 339 320 302 285 269 254 240 226 "
	+ "214 202 190 180 170 160 151 143 135 127 120 113"
)
## The vibrato's sine at its peak: a depth of 1 moves the period by up to this / 128.
const VIBRATO_PEAK := 255.0
## Four channels at full volume sum to 1: no clipping, whatever plays.
const CHANNEL_GAIN := 0.25
## In stereo, the share of a channel on its own side.
const OWN_SIDE := 0.75
const LEFT_CHANNELS: Array[int] = [0, 3]
## The generator's default beat: four rows (a piece may say another, see MusicPiece).
const ROWS_PER_BEAT := 4
## How long a volume change, a note's start and the fade of the note before take.
const RAMP_SECONDS := 0.002

const EFFECT_ARPEGGIO := 0x0
const EFFECT_PORTAMENTO_UP := 0x1
const EFFECT_PORTAMENTO_DOWN := 0x2
const EFFECT_TONE_PORTAMENTO := 0x3
const EFFECT_VIBRATO := 0x4
const EFFECT_VOLUME_SLIDE := 0xA
const EFFECT_VOLUME := 0xC
const EFFECT_BREAK := 0xD
const EFFECT_EXTENDED := 0xE
const EXTENDED_NOTE_CUT := 0xC
const EFFECT_SPEED := 0xF


## What a channel plays: its sample, where in it, at what period and volume, and the effect of the
## row.
class Channel:
	var sample: TrackerModule.Sample
	## The sample of the last cell that named one: the next note plays it.
	var next_sample: TrackerModule.Sample
	var position := 0.0
	var is_playing := false
	## The note's period, which portamentos move; arpeggio and vibrato only change what plays.
	var period := 0
	var played_period := 0
	var target_period := 0
	var volume := 0
	var effect := 0
	var parameter := 0
	var vibrato_position := 0
	## The gain the channel mixes at, moving to `ramp_target` by `gain_step` a frame for
	## `ramp_frames` more frames.
	var gain := 0.0
	var ramp_target := 0.0
	var gain_step := 0.0
	var ramp_frames := 0
	## The note before the last struck one, while it fades out.
	var fading: Channel


static var _periods := PackedInt32Array(
	Array(PERIOD_TABLE.split(" ")).map(func(period: String) -> int: return int(period))
)

var module: TrackerModule
var mix_rate := 44100
var is_stereo := false
## How many rows a beat has.
var rows_per_beat := ROWS_PER_BEAT
## The length of a beat in the last render, in seconds: `rows_per_beat` rows at the speed and tempo
## of its first row, in whole samples (see the ticks above).
var beat_seconds := 0.0

var _task_id := -1
var _rendered: AudioStreamWAV
var _ramp_length := 1


func _init(tracker_module: TrackerModule, rate := 44100, stereo := false) -> void:
	module = tracker_module
	mix_rate = rate
	is_stereo = stereo
	_ramp_length = maxi(1, roundi(mix_rate * RAMP_SECONDS))


## Starts rendering `parts` (see `render`) on a WorkerThreadPool thread; `is_done` tells when
## `take` has it.
func start(parts: Array[Vector2i], loops := false) -> void:
	assert(_task_id < 0, "one render at a time")
	_task_id = WorkerThreadPool.add_task(func() -> void: _rendered = render(parts, loops))


## Whether a render was started and not taken yet.
func is_rendering() -> bool:
	return _task_id >= 0


func is_done() -> bool:
	return _task_id >= 0 and WorkerThreadPool.is_task_completed(_task_id)


## The stream of the render `start` began (waiting for it if it isn't done).
func take() -> AudioStreamWAV:
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	var stream := _rendered
	_rendered = null
	return stream


## The rows the order list plays once through: each pattern up to its break (D00), or all 64.
func rows_once_through() -> int:
	var rows := 0
	for pattern in module.order:
		var played := TrackerModule.PATTERN_ROWS
		for row in TrackerModule.PATTERN_ROWS:
			if _breaks(module.patterns[pattern], row):
				played = row + 1
				break
		rows += played
	return rows


## `parts` rendered, one after the other; null, with an error, for a part outside the order list.
## A stream that `loops` is the parts' second time through, rendered after the first: it starts as
## they sound after their own end, the notes left sounding there fading out into it, so its wrap
## is the music repeating, sample for sample, and it is flagged to loop over all of it. It takes
## twice as long to render.
func render(parts: Array[Vector2i], loops := false) -> AudioStreamWAV:
	for part in parts:
		if part.x < 0 or part.x >= module.order.size() or part.y < 0:
			push_error("ModuleRenderer: part %s is outside the order list" % part)
			return null
	var played := parts.duplicate()
	if loops:
		played.append_array(parts)
	var second_start := 0
	var channels: Array[Channel] = []
	for index in TrackerModule.CHANNELS:
		channels.append(Channel.new())
	var speed := 6
	var tempo := 125
	var mix := PackedFloat32Array()
	var frames := 0
	var first_row_frames := 0
	for part_index in played.size():
		if part_index == parts.size():
			second_start = frames
		var part: Vector2i = played[part_index]
		var order := part.x
		var row := 0
		for row_number in part.y:
			var cells := module.patterns[module.order[order]]
			var break_row := -1
			for index in TrackerModule.CHANNELS:
				var at := (row * TrackerModule.CHANNELS + index) * TrackerModule.CELL_SIZE
				var effect := cells[at + 2]
				var parameter := cells[at + 3]
				_start_row(channels[index], cells[at], cells[at + 1], effect, parameter)
				if effect == EFFECT_SPEED and parameter > 0:
					if parameter < 32:
						speed = parameter
					else:
						tempo = parameter
				elif effect == EFFECT_BREAK:
					break_row = (parameter >> 4) * 10 + (parameter & 0x0F)
			var tick_frames := mix_rate * 5 / (2 * tempo)
			if first_row_frames == 0:
				first_row_frames = speed * tick_frames
			for tick in speed:
				if tick > 0:
					for channel in channels:
						_play_tick(channel, tick)
				mix.resize((frames + tick_frames) * (2 if is_stereo else 1))
				for index in TrackerModule.CHANNELS:
					var channel := channels[index]
					var gain := CHANNEL_GAIN * channel.volume / 64.0
					if gain != channel.ramp_target:
						_ramp(channel, gain)
					_mix(channel, index, mix, frames, tick_frames)
					if channel.fading:
						var fading := channel.fading
						_mix(fading, index, mix, frames, mini(tick_frames, fading.ramp_frames))
						if fading.ramp_frames == 0 or not fading.is_playing:
							channel.fading = null
				frames += tick_frames
			row += 1
			if break_row >= 0 or row == TrackerModule.PATTERN_ROWS:
				order = (order + 1) % module.order.size()
				row = maxi(break_row, 0)
	if loops:
		mix = mix.slice(second_start * (2 if is_stereo else 1))
	beat_seconds = first_row_frames * rows_per_beat / float(mix_rate)
	return _stream(mix, loops)


## What a row's cell does on its first tick.
func _start_row(channel: Channel, period: int, sample: int, effect: int, parameter: int) -> void:
	if sample > 0:
		channel.next_sample = module.samples[sample - 1]
		channel.volume = channel.next_sample.volume
	if period > 0:
		if effect == EFFECT_TONE_PORTAMENTO:
			channel.target_period = period
		else:
			if channel.is_playing and (channel.gain > 0.0 or channel.ramp_frames > 0):
				channel.fading = _fading_copy(channel)
			channel.gain = 0.0
			channel.ramp_target = 0.0
			channel.ramp_frames = 0
			channel.sample = channel.next_sample
			channel.period = period
			channel.position = 0.0
			channel.is_playing = channel.sample != null
			channel.vibrato_position = 0
	channel.effect = effect
	channel.parameter = parameter
	channel.played_period = channel.period
	if effect == EFFECT_VOLUME:
		channel.volume = mini(parameter, 64)
	elif effect == EFFECT_EXTENDED and parameter == EXTENDED_NOTE_CUT << 4:
		channel.volume = 0


## The note `channel` plays, going on beside it while it fades out.
func _fading_copy(channel: Channel) -> Channel:
	var fading := Channel.new()
	fading.sample = channel.sample
	fading.position = channel.position
	fading.is_playing = true
	fading.played_period = channel.played_period
	fading.gain = channel.gain
	_ramp(fading, 0.0)
	return fading


## Moves the channel's gain to `target` over a ramp.
func _ramp(channel: Channel, target: float) -> void:
	channel.ramp_target = target
	channel.gain_step = (target - channel.gain) / _ramp_length
	channel.ramp_frames = _ramp_length


## What a channel's effect does on a later tick of its row.
func _play_tick(channel: Channel, tick: int) -> void:
	var x := channel.parameter >> 4
	var y := channel.parameter & 0x0F
	match channel.effect:
		EFFECT_ARPEGGIO:
			if channel.parameter > 0 and tick % 3 > 0:
				var semitones := x if tick % 3 == 1 else y
				channel.played_period = _arpeggio_period(channel.period, semitones)
			else:
				channel.played_period = channel.period
		EFFECT_PORTAMENTO_UP:
			channel.period = maxi(channel.period - channel.parameter, TrackerModule.LOWEST_PERIOD)
			channel.played_period = channel.period
		EFFECT_PORTAMENTO_DOWN:
			channel.period = mini(channel.period + channel.parameter, TrackerModule.HIGHEST_PERIOD)
			channel.played_period = channel.period
		EFFECT_TONE_PORTAMENTO:
			if channel.period < channel.target_period:
				channel.period = mini(channel.period + channel.parameter, channel.target_period)
			else:
				channel.period = maxi(channel.period - channel.parameter, channel.target_period)
			channel.played_period = channel.period
		EFFECT_VIBRATO:
			var phase := channel.vibrato_position / 64.0 * TAU
			channel.played_period = channel.period + roundi(VIBRATO_PEAK * sin(phase) * y / 128.0)
			channel.vibrato_position = (channel.vibrato_position + x) & 63
		EFFECT_VOLUME_SLIDE:
			channel.volume = clampi(channel.volume + x - y, 0, 64)
		EFFECT_EXTENDED:
			if x == EXTENDED_NOTE_CUT and tick == y:
				channel.volume = 0


## The period an arpeggio plays `semitones` above `period` (on the ticks that step), as ProTracker
## finds it: the first period of the table at or below it, and that many steps up.
static func _arpeggio_period(period: int, semitones: int) -> int:
	var note := 0
	while note < _periods.size() - 1 and _periods[note] > period:
		note += 1
	return _periods[mini(note + semitones, _periods.size() - 1)]


## Adds `frame_count` frames of a channel into `mix` from frame `first`: the sample stepped through
## at its period, looped or played to its end. Most of a render's time is spent here, so mono and
## stereo have a loop each.
func _mix(
	channel: Channel, index: int, mix: PackedFloat32Array, first: int, frame_count: int
) -> void:
	if not channel.is_playing or channel.played_period <= 0:
		return
	var data := channel.sample.data
	var step := PAL_RATE / (channel.played_period * mix_rate)
	var gain := channel.gain
	var gain_step := channel.gain_step
	var ramp_frames := channel.ramp_frames
	var position := channel.position
	var loop_length := float(channel.sample.loop_length)
	var end := float(data.size())
	# What the last sample leads into: the loop's start, or silence after a one-shot.
	var after_end := 0.0
	if loop_length > 0.0:
		end = channel.sample.loop_start + loop_length
		after_end = data[channel.sample.loop_start]
	var last_index := int(end) - 1
	var frame := first
	var last := first + frame_count
	if is_stereo:
		var left := OWN_SIDE if LEFT_CHANNELS.has(index) else 1.0 - OWN_SIDE
		var right := 1.0 - left
		while frame < last:
			if position >= end:
				if loop_length <= 0.0:
					channel.is_playing = false
					break
				# Once round the loop, or more where a short loop plays at a high pitch.
				position = channel.sample.loop_start + fmod(position - end, loop_length)
			var at := int(position)
			var next := data[at + 1] if at < last_index else after_end
			if ramp_frames > 0:
				ramp_frames -= 1
				gain = channel.ramp_target if ramp_frames == 0 else gain + gain_step
			var value := lerpf(data[at], next, position - at) * gain
			mix[frame * 2] += value * left
			mix[frame * 2 + 1] += value * right
			position += step
			frame += 1
	else:
		while frame < last:
			if position >= end:
				if loop_length <= 0.0:
					channel.is_playing = false
					break
				# Once round the loop, or more where a short loop plays at a high pitch.
				position = channel.sample.loop_start + fmod(position - end, loop_length)
			var at := int(position)
			var next := data[at + 1] if at < last_index else after_end
			if ramp_frames > 0:
				ramp_frames -= 1
				gain = channel.ramp_target if ramp_frames == 0 else gain + gain_step
			mix[frame] += lerpf(data[at], next, position - at) * gain
			position += step
			frame += 1
	channel.position = position
	channel.gain = gain
	channel.ramp_frames = ramp_frames


## The mix as a 16-bit AudioStreamWAV, looping over all of it when `loops`. Reading the stream's
## data back copies it, so what a player needs to know of it is set here, on the worker.
func _stream(mix: PackedFloat32Array, loops: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for index in mix.size():
		data.encode_s16(index * 2, int(mix[index] * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = is_stereo
	stream.data = data
	if loops:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = mix.size() / (2 if is_stereo else 1)
	return stream


static func _breaks(cells: PackedInt32Array, row: int) -> bool:
	for channel in TrackerModule.CHANNELS:
		var at := (row * TrackerModule.CHANNELS + channel) * TrackerModule.CELL_SIZE
		if cells[at + 2] == EFFECT_BREAK:
			return true
	return false
