class_name MusicGen
extends RefCounted
## Seeded ambient score events from audio balance data.


static func make_bar(audio: Dictionary, bar_index: int, seed: int) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + bar_index * int(audio.music_seed_stride)
	var roots: Array = audio.music_root_notes_midi
	var root: int = roots[posmod(bar_index, roots.size())]
	var second_bass: int = root
	if rng.randf() >= float(audio.music_bass_repeat_chance):
		second_bass -= int(audio.music_bass_fifth_down)
	var bass_duration: float = audio.music_bass_duration_beats
	var events: Array[Dictionary] = [
		{"beat": 0, "midi_note": root, "role": "bass", "duration_beats": bass_duration},
		{
			"beat": int(audio.music_bass_second_beat),
			"midi_note": second_bass,
			"role": "bass",
			"duration_beats": bass_duration
		}
	]
	events.append_array(_make_pads(audio, root, rng))
	events.append_array(_make_leads(audio, root, rng))
	events.append_array(_make_beat(audio))
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.beat < b.beat)
	return events


static func _make_pads(
	audio: Dictionary, root: int, rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var pad_count: int = 1
	if rng.randf() < float(audio.music_extra_pad_chance):
		pad_count += 1
	var first_pad_beat: int = rng.randi_range(
		int(audio.music_pad_min_beat), int(audio.music_pad_max_beat)
	)
	var intervals: Array = audio.music_scale_intervals
	var events: Array[Dictionary] = []
	for pad_index: int in pad_count:
		var beat: int = first_pad_beat
		if pad_index > 0:
			beat = rng.randi_range(int(audio.music_pad_min_beat), int(audio.music_pad_max_beat))
			if beat == first_pad_beat:
				beat = _alternate_beat(beat, audio)
		var interval: int = intervals[rng.randi_range(0, intervals.size() - 1)]
		events.append(
			{
				"beat": beat,
				"midi_note": root + int(audio.music_pad_octave_semitones) + interval,
				"role": "pad",
				"duration_beats": float(audio.music_pad_duration_beats)
			}
		)
	return events


static func _alternate_beat(beat: int, audio: Dictionary) -> int:
	if beat < int(audio.music_pad_max_beat):
		return beat + 1
	return beat - 1


## Short high notes on distinct eighth-note positions, above the pads.
static func _make_leads(
	audio: Dictionary, root: int, rng: RandomNumberGenerator
) -> Array[Dictionary]:
	var positions: Array[int] = []
	for eighth: int in int(audio.music_beats_per_bar) * 2:
		positions.append(eighth)
	var count: int = rng.randi_range(
		int(audio.music_lead_min_notes), int(audio.music_lead_max_notes)
	)
	var intervals: Array = audio.music_scale_intervals
	var events: Array[Dictionary] = []
	for _note: int in count:
		var eighth: int = positions.pop_at(rng.randi_range(0, positions.size() - 1))
		var interval: int = intervals[rng.randi_range(0, intervals.size() - 1)]
		events.append(
			{
				"beat": eighth * 0.5,
				"midi_note": root + int(audio.music_lead_octave_semitones) + interval,
				"role": "lead",
				"duration_beats": float(audio.music_lead_duration_beats)
			}
		)
	return events


## Fixed half-time pattern: the kick drops from start to end pitch, the hat is a noise tick.
static func _make_beat(audio: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for beat: Variant in audio.music_kick_beats:
		events.append(
			{
				"beat": float(beat),
				"midi_note": int(audio.music_kick_start_midi),
				"end_midi_note": int(audio.music_kick_end_midi),
				"role": "kick",
				"duration_beats": float(audio.music_kick_duration_beats)
			}
		)
	for beat: Variant in audio.music_hat_beats:
		events.append(
			{
				"beat": float(beat),
				"role": "hat",
				"duration_beats": float(audio.music_hat_duration_beats)
			}
		)
	return events
