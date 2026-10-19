extends GutTest
## Synth mixes every sample in GDScript at a reduced rate, so every tone in balance.json must stay
## below half of it (the Nyquist frequency) or it would alias.


func test_every_tone_is_below_the_nyquist_frequency() -> void:
	var audio: Dictionary = Balance.section("audio")
	var tones: Array = (
		audio.pad_notes_hz + audio.success_notes_hz + [audio.cpu_tone_hz, audio.click_hz]
	)
	for hz: Variant in tones:
		assert_lt(float(hz), Synth.MIX_RATE / 2.0, "%s Hz would alias" % hz)
