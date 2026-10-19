extends Node
## Haptic feedback: phone vibration and gamepad rumble (SPEC: Platforms and input > Haptics;
## Minigame: CPU > Haptics; Result overlay). Every call respects GameState.settings.haptics.
## Numbers come from balance.json "haptics". `active` and `last_pulse_ms` let tests observe
## what the hardware would do.

const MS_PER_S := 1000.0

## A hold rumble is running (CPU tile lit or held).
var active: bool = false
## Length of the last pulse requested, in ms (0 when haptics are off).
var last_pulse_ms: int = 0


## Light pulse on every input (tap, toggle, purchase).
func pulse() -> void:
	_pulse(Balance.get_int("haptics", "pulse_ms"), Balance.get_num("haptics", "pulse_strength"))


## Continuous rumble until stop_hold(); phones get one vibration at the start.
func start_hold() -> void:
	if active or not _enabled():
		return
	active = true
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(Balance.get_int("haptics", "pulse_ms"))
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, Balance.get_num("haptics", "hold_strength"), 0.0, 0.0)


func stop_hold() -> void:
	if not active:
		return
	active = false
	for device: int in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)


## Short double pulse.
func success() -> void:
	var ms: int = Balance.get_int("haptics", "success_pulse_ms")
	var strength: float = Balance.get_num("haptics", "pulse_strength")
	_pulse(ms, strength)
	if _enabled():
		var gap_s: float = (ms + Balance.get_int("haptics", "success_gap_ms")) / MS_PER_S
		get_tree().create_timer(gap_s).timeout.connect(_pulse.bind(ms, strength))


## One long pulse.
func fail() -> void:
	_pulse(Balance.get_int("haptics", "fail_pulse_ms"), Balance.get_num("haptics", "hold_strength"))


func _enabled() -> bool:
	return GameState.settings.get("haptics", true)


func _pulse(ms: int, strength: float) -> void:
	if not _enabled():
		return
	last_pulse_ms = ms
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, strength, 0.0, ms / MS_PER_S)
