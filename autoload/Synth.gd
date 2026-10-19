extends Node
## Runtime-synthesized audio via AudioStreamGenerator, no audio files (SPEC: Visual and audio style).
## Pentatonic pad notes, RAM click, CPU sine tone, success arpeggio, fail noise burst.
## Respects GameState.settings.sound. All frequencies and durations come from balance.json "audio".

enum Wave { SINE, NOISE }

const MIX_RATE := 44100.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _next_voice_id: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.05
	_player = AudioStreamPlayer.new()
	_player.stream = generator
	# Web exports default to "sample" playback, which cannot play a generator.
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	_fill_buffer()


## Pad tone for Storage pad `index` (pentatonic, wraps around). `volume` scales the note (decoy plays quieter).
func play_note(index: int, duration_ms: float, volume: float = 1.0) -> void:
	var notes: Array = Balance.section("audio").get("pad_notes_hz", [])
	if notes.is_empty():
		return
	var length_ms: float = maxf(duration_ms, Balance.get_num("audio", "pad_note_min_ms"))
	_add_voice(Wave.SINE, float(notes[index % notes.size()]), length_ms, volume)


func play_click() -> void:
	_add_voice(
		Wave.SINE, Balance.get_num("audio", "click_hz"), Balance.get_num("audio", "click_ms"), 1.0
	)


## Starts a sustained tone (CPU tile). Returns an id for stop_tone, or 0 if sound is off.
func start_tone() -> int:
	return _add_voice(Wave.SINE, Balance.get_num("audio", "cpu_tone_hz"), -1.0, 1.0)


func stop_tone(id: int) -> void:
	for voice: Dictionary in _voices:
		if voice.id == id and voice.length < 0:
			voice.length = voice.t + _ms_to_samples(Balance.get_num("audio", "release_ms"))


func play_success() -> void:
	var note_ms: float = Balance.get_num("audio", "success_note_ms")
	var delay_ms: float = 0.0
	for hz: Variant in Balance.section("audio").get("success_notes_hz", []):
		_add_voice(Wave.SINE, float(hz), note_ms, 1.0, delay_ms)
		delay_ms += note_ms


func play_fail() -> void:
	_add_voice(Wave.NOISE, 0.0, Balance.get_num("audio", "fail_noise_ms"), 0.6)


func stop_all() -> void:
	_voices.clear()


func _add_voice(
	wave: Wave, hz: float, length_ms: float, volume: float, delay_ms: float = 0.0
) -> int:
	if not GameState.settings.get("sound", true):
		return 0
	var id: int = _next_voice_id
	_next_voice_id += 1
	(
		_voices
		. append(
			{
				"id": id,
				"wave": wave,
				"step": TAU * hz / MIX_RATE,
				"phase": 0.0,
				"t": -_ms_to_samples(delay_ms),
				"length": _ms_to_samples(length_ms) if length_ms >= 0.0 else -1,
				"amp": volume * Balance.get_num("audio", "volume"),
			}
		)
	)
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
	var env: float = minf(1.0, float(t) / attack)
	if voice.length >= 0:
		env = minf(env, float(voice.length - t) / release)
	var raw: float
	if voice.wave == Wave.NOISE:
		raw = _rng.randf_range(-1.0, 1.0)
	else:
		raw = sin(voice.phase)
		voice.phase = fmod(voice.phase + voice.step, TAU)
	return raw * env * voice.amp


static func _ms_to_samples(ms: float) -> int:
	return int(ms * MIX_RATE / 1000.0)
