extends "res://tests/hardwire_test.gd"
## Synth mixes every sample in GDScript at a reduced rate, so every tone in balance.json must stay
## below half of it (the Nyquist frequency) or it would alias.


func test_every_tone_is_below_the_nyquist_frequency() -> void:
	var audio: Dictionary = Balance.section("audio")
	var tones: Array = (
		audio.pad_notes_hz
		+ audio.success_notes_hz
		+ [audio.cpu_tone_hz, audio.click_hz, audio.key_hz, audio.relay_hz, audio.tick_hz]
		+ [audio.boot_to_hz, audio.hum_cutoff_hz, audio.relay_end_hz]
	)
	for hz: Variant in tones:
		assert_lt(float(hz), Synth.MIX_RATE / 2.0, "%s Hz would alias" % hz)


## D-041: every blip and the power-on sweep are silent with sound off and voices with it on.
func test_fx_and_boot_respect_the_sound_setting() -> void:
	GameState.settings.sound = false
	for name: String in ["key", "relay", "tick", "click"]:
		assert_eq(Synth.play_fx(name), 0, name)
	assert_eq(Synth.play_boot(), 0)
	GameState.settings.sound = true
	for name: String in ["key", "relay", "tick", "click"]:
		assert_gt(Synth.play_fx(name), 0, name)
	assert_gt(Synth.play_boot(), 0)
	Synth.stop_all()


## D-041: the hum starts with the score and stops with it.
func test_hum_runs_with_the_score() -> void:
	GameState.settings.sound = true
	Synth.set_music_enabled(false)
	Synth.set_music_enabled(true)
	Synth._process(0.0)
	assert_true(Synth.is_playing(Synth.hum_id), "hum voice while the score runs")
	Synth.set_music_enabled(false)
	assert_false(Synth.is_playing(Synth.hum_id), "hum stops with the score")
	Synth.stop_all()
