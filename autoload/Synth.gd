extends Node
## Runtime-synthesized audio via AudioStreamGenerator, no audio files (SPEC: Visual and audio
## style): score with a hum, pad notes, clicks, CPU tone, result sounds, power-on sweep. Every
## button clicks through the hook below (D-041). Tuning: balance.json "audio"; respects Sound.

enum Wave { SINE, NOISE }

## Mixed in GDScript at a low rate (phones); every tone stays under half of it (test_synth).
const MIX_RATE := 22050.0
const MIDI_A4 := 69
const MIDI_A4_HZ := 440.0
const SEMITONES_PER_OCTAVE := 12.0
const SECONDS_PER_MINUTE := 60.0

## The hum's voice id while the score runs (0 when silent) and blips sounded so far; for tests.
var hum_id: int = 0
var fx_played: int = 0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _next_voice_id: int = 1
var _music_seed: int
var _music_bar_index: int = 0
var _music_bar_elapsed_s: float = 0.0
var _music_events: Array[Dictionary] = []
var _music_event_index: int = 0
var _music_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = Balance.get_num("audio", "buffer_s")
	_player = AudioStreamPlayer.new()
	_player.stream = generator
	# Web exports default to "sample" playback, which cannot play a generator.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_rng.randomize()
	_music_seed = _rng.randi()
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(play_fx.bind("key"))


func _process(delta: float) -> void:
	_advance_music(delta)
	_fill_buffer()


## Pad tone for Storage pad `index` (pentatonic, wraps around). `volume` scales the note (decoy
## plays quieter).
func play_note(index: int, duration_ms: float, volume: float = 1.0) -> void:
	var length_ms: float = maxf(duration_ms, Balance.get_num("audio", "pad_note_min_ms"))
	_add_voice(Wave.SINE, _pad_hz(index), length_ms, volume)


## Sustained pad tone while a Storage pad is held, at least pad_note_min_ms. Returns an id for
## stop_tone, or 0 if sound is off.
func start_note(index: int) -> int:
	var min_ms: float = Balance.get_num("audio", "pad_note_min_ms")
	return _add_voice(Wave.SINE, _pad_hz(index), -1.0, 1.0, {"min_ms": min_ms})


static func _pad_hz(index: int) -> float:
	var notes: Array = Balance.section("audio").pad_notes_hz
	return float(notes[index % notes.size()])


## A short blip named by its balance keys: "key" (buttons), "relay" (puzzle phase; drops to
## relay_end_hz), "tick" (boot typing), "click" (RAM toggle). Voice id, 0 when sound is off.
func play_fx(fx: String) -> int:
	var audio: Dictionary = Balance.section("audio")
	var hz: float = audio[fx + "_hz"]
	var ms: float = audio[fx + "_ms"]
	var options := {"end_hz": audio.get(fx + "_end_hz", hz), "release_ms": ms / 2}  # short release
	var id: int = _add_voice(Wave.SINE, hz, ms, audio[fx + "_volume"], options)
	fx_played += int(id > 0)
	return id


## Power-on (Boot screen): a low sine sweep under a soft filtered noise burst.
func play_boot() -> int:
	var audio: Dictionary = Balance.section("audio")
	_add_voice(
		Wave.NOISE, 0.0, audio.boot_ms, audio.boot_noise_volume, {"lowpass": _lowpass_coefficient()}
	)
	return _add_voice(
		Wave.SINE,
		audio.boot_from_hz,
		audio.boot_ms,
		audio.boot_volume,
		{"end_hz": audio.boot_to_hz}
	)


## Starts a sustained tone (CPU tile). Returns an id for stop_tone, or 0 if sound is off.
func start_tone() -> int:
	return _add_voice(Wave.SINE, Balance.get_num("audio", "cpu_tone_hz"), -1.0, 1.0)


func stop_tone(id: int) -> void:
	for voice: Dictionary in _voices:
		if voice.id == id and voice.length < 0:
			var release: int = _ms_to_samples(Balance.get_num("audio", "release_ms"))
			voice.length = maxi(voice.t + release, voice.min_length)


func is_playing(id: int) -> bool:
	return _voices.any(func(voice: Dictionary) -> bool: return voice.id == id)


func play_success() -> void:
	var note_ms: float = Balance.get_num("audio", "success_note_ms")
	var delay_ms: float = 0.0
	for hz: Variant in Balance.section("audio").get("success_notes_hz", []):
		_add_voice(Wave.SINE, float(hz), note_ms, 1.0, {"delay_ms": delay_ms})
		delay_ms += note_ms


func play_fail() -> void:
	_add_voice(
		Wave.NOISE,
		0.0,
		Balance.get_num("audio", "fail_noise_ms"),
		Balance.get_num("audio", "fail_volume")
	)


func stop_all() -> void:
	_voices.clear()


func set_music_enabled(enabled: bool) -> void:
	if enabled == _music_enabled:
		return
	_music_enabled = enabled
	_music_bar_elapsed_s = 0.0
	if enabled:
		_set_music_bar()
	else:
		_voices = _voices.filter(func(voice: Dictionary) -> bool: return not voice.music)
		hum_id = 0


## The hum runs with the score: one low-passed noise voice, restarted after sound was off.
func _ensure_hum() -> void:
	if is_playing(hum_id):
		return
	var audio: Dictionary = Balance.section("audio")
	var options := {
		"music": true, "attack_ms": audio.hum_attack_ms, "lowpass": _lowpass_coefficient()
	}
	hum_id = _add_voice(Wave.NOISE, 0.0, -1.0, audio.hum_volume, options)


static func _lowpass_coefficient() -> float:
	return 1.0 - exp(-TAU * Balance.get_num("audio", "hum_cutoff_hz") / MIX_RATE)


func is_music_enabled() -> bool:
	return _music_enabled


func _add_voice(
	wave: Wave, hz: float, length_ms: float, volume: float, options: Dictionary = {}
) -> int:
	if not GameState.settings.get("sound", true):
		return 0
	var delay_ms: float = float(options.get("delay_ms", 0.0))
	var attack_ms: float = float(options.get("attack_ms", -1.0))
	var release_ms: float = float(options.get("release_ms", -1.0))
	var id: int = _next_voice_id
	_next_voice_id += 1
	var voice := {
		"id": id,
		"wave": wave,
		"step": TAU * hz / MIX_RATE,
		"end_step": TAU * float(options.get("end_hz", hz)) / MIX_RATE,
		"phase": 0.0,
		"t": -_ms_to_samples(delay_ms),
		"length": _ms_to_samples(length_ms) if length_ms >= 0.0 else -1,
		"amp": volume * Balance.get_num("audio", "volume"),
		"attack": _ms_to_samples(attack_ms) if attack_ms >= 0.0 else 0,
		"release": _ms_to_samples(release_ms) if release_ms >= 0.0 else 0,
		"music": options.get("music", false),
		"min_length": _ms_to_samples(float(options.get("min_ms", 0.0))),
		"lowpass": float(options.get("lowpass", 0.0)),
		"lp": 0.0,
	}
	_voices.append(voice)
	return id


func _fill_buffer() -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var attack: int = maxi(1, _ms_to_samples(Balance.get_num("audio", "attack_ms")))
	var release: int = maxi(1, _ms_to_samples(Balance.get_num("audio", "release_ms")))
	var buffer := PackedVector2Array()
	buffer.resize(frames)
	for i: int in frames:
		var sample: float = 0.0
		for voice: Dictionary in _voices:
			sample += _next_sample(voice, attack, release)
		buffer[i] = Vector2(sample, sample)
	_playback.push_buffer(buffer)
	_voices = _voices.filter(func(v: Dictionary) -> bool: return v.length < 0 or v.t < v.length)


func _next_sample(voice: Dictionary, attack: int, release: int) -> float:
	var t: int = voice.t
	voice.t = t + 1
	if t < 0 or (voice.length >= 0 and t >= voice.length):
		return 0.0
	var voice_attack: int = voice.attack if voice.attack > 0 else attack
	var voice_release: int = voice.release if voice.release > 0 else release
	var env: float = minf(1.0, float(t) / voice_attack)
	if voice.length >= 0:
		env = minf(env, float(voice.length - t) / voice_release)
	var raw: float
	if voice.wave == Wave.NOISE:
		raw = _rng.randf_range(-1.0, 1.0)
		if voice.lowpass > 0.0:
			voice.lp += voice.lowpass * (raw - voice.lp)
			raw = voice.lp
	else:
		raw = sin(voice.phase)
		var step: float = voice.step
		if voice.length > 0:
			step = lerpf(voice.step, voice.end_step, float(t) / voice.length)
		voice.phase = fmod(voice.phase + step, TAU)
	return raw * env * voice.amp


static func _ms_to_samples(ms: float) -> int:
	return int(ms * MIX_RATE / 1000.0)


func _advance_music(delta: float) -> void:
	if not _music_enabled:
		return
	_ensure_hum()
	var audio: Dictionary = Balance.section("audio")
	var beat_s: float = SECONDS_PER_MINUTE / float(audio.music_bpm)
	var bar_s: float = beat_s * float(audio.music_beats_per_bar)
	_music_bar_elapsed_s += delta
	if _music_bar_elapsed_s >= bar_s:
		var bars_passed: int = floori(_music_bar_elapsed_s / bar_s)
		_music_bar_elapsed_s = fmod(_music_bar_elapsed_s, bar_s)
		_music_bar_index += bars_passed
		_set_music_bar()
	while _music_event_index < _music_events.size():
		var event: Dictionary = _music_events[_music_event_index]
		if float(event.beat) * beat_s > _music_bar_elapsed_s:
			return
		_play_music_event(event, beat_s)
		_music_event_index += 1


func _set_music_bar() -> void:
	_music_events = MusicGen.make_bar(Balance.section("audio"), _music_bar_index, _music_seed)
	_music_event_index = 0


## Each role's envelope and volume come from balance.json "audio" → music_<role>_*.
func _play_music_event(event: Dictionary, beat_s: float) -> void:
	var audio: Dictionary = Balance.section("audio")
	var role: String = event.role
	var duration_ms: float = float(event.duration_beats) * beat_s * 1000.0
	var volume: float = audio["music_%s_volume" % role]
	var options := {
		"attack_ms": audio["music_%s_attack_ms" % role],
		"release_ms": audio["music_%s_release_ms" % role],
		"music": true,
	}
	if not event.has("midi_note"):
		_add_voice(Wave.NOISE, 0.0, duration_ms, volume, options)
		return
	var note_hz: float = _midi_to_hz(event.midi_note)
	if event.has("end_midi_note"):
		options.end_hz = _midi_to_hz(event.end_midi_note)
	_add_voice(Wave.SINE, note_hz, duration_ms, volume, options)
	if role == "bass":
		_add_voice(Wave.SINE, note_hz * 2.0, duration_ms, audio.music_harmonic_volume, options)


static func _midi_to_hz(note: int) -> float:
	return MIDI_A4_HZ * pow(2.0, float(note - MIDI_A4) / SEMITONES_PER_OCTAVE)
