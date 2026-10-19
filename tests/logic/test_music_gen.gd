extends GutTest
## MusicGen against SPEC: restrained bass pulse, sparse pentatonic tones, seeded variation.


func test_bar_has_two_low_bass_notes_and_sparse_pads() -> void:
	var audio: Dictionary = Balance.section("audio")
	var events: Array[Dictionary] = MusicGen.make_bar(audio, 0, 17)
	var bass: Array[Dictionary] = events.filter(
		func(event: Dictionary) -> bool: return event.role == "bass"
	)
	var pads: Array[Dictionary] = events.filter(
		func(event: Dictionary) -> bool: return event.role == "pad"
	)
	assert_eq(bass.size(), 2)
	assert_between(pads.size(), 1, 2)
	assert_eq(int(bass[0].beat), 0)
	assert_eq(int(bass[1].beat), int(audio.music_bass_second_beat))
	for event: Dictionary in bass:
		assert_between(
			int(event.midi_note), int(audio.music_bass_min_midi), int(audio.music_bass_max_midi)
		)


func test_pad_notes_stay_in_the_minor_pentatonic_palette() -> void:
	var audio: Dictionary = Balance.section("audio")
	var root: int = audio.music_root_notes_midi[0]
	for seed: int in 20:
		for event: Dictionary in MusicGen.make_bar(audio, 0, seed):
			if event.role == "pad":
				var interval: int = event.midi_note - root - audio.music_pad_octave_semitones
				assert_has(audio.music_scale_intervals, float(interval), "pad in scale")


func test_same_seed_repeats_and_different_seeds_vary() -> void:
	var audio: Dictionary = Balance.section("audio")
	assert_eq(MusicGen.make_bar(audio, 2, 21), MusicGen.make_bar(audio, 2, 21))
	var arrangements := {}
	for seed: int in 20:
		arrangements[str(MusicGen.make_bar(audio, 2, seed))] = true
	assert_gt(arrangements.size(), 10, "seed changes score details")


func test_harmony_moves_through_the_four_bar_cycle() -> void:
	var audio: Dictionary = Balance.section("audio")
	var roots: Array = audio.music_root_notes_midi
	assert_eq(roots.size(), 4, "four-bar progression")
	for bar: int in roots.size():
		var events: Array[Dictionary] = MusicGen.make_bar(audio, bar, 4)
		var bass: Dictionary = {}
		for event: Dictionary in events:
			if event.role == "bass":
				bass = event
				break
		assert_eq(int(bass.midi_note), int(roots[bar]))


func test_beat_has_kicks_on_the_bass_beats_and_hats_on_the_offbeats() -> void:
	var audio: Dictionary = Balance.section("audio")
	var kicks: Array[float] = []
	var hats: Array[float] = []
	for event: Dictionary in MusicGen.make_bar(audio, 0, 5):
		if event.role == "kick":
			kicks.append(float(event.beat))
		elif event.role == "hat":
			hats.append(float(event.beat))
	assert_eq(kicks, [0.0, 2.0] as Array[float])
	assert_eq(hats, [0.5, 1.5, 2.5, 3.5] as Array[float])


func test_lead_notes_sit_high_on_the_eighth_grid_in_the_palette() -> void:
	var audio: Dictionary = Balance.section("audio")
	var root: int = audio.music_root_notes_midi[1]
	for seed: int in 20:
		var beats := {}
		for event: Dictionary in MusicGen.make_bar(audio, 1, seed):
			if event.role != "lead":
				continue
			var interval: int = event.midi_note - root - 36
			assert_has(audio.music_scale_intervals, float(interval), "lead in scale")
			assert_eq(fmod(float(event.beat) * 2.0, 1.0), 0.0, "lead on an eighth")
			assert_false(beats.has(event.beat), "one lead note per position")
			beats[event.beat] = true
		assert_between(beats.size(), 2, 3)
