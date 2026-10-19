extends Node
## Haptic feedback: phone vibration and gamepad rumble (SPEC: Platforms and input > Haptics;
## Minigame: Storage, RAM and CPU > Watch phase; Result overlay). Every call respects
## GameState.settings.haptics. Numbers come from balance.json "haptics". Every button pulses
## through the hook below (D-034), so screens never ask for it. `active`, `last_pulse_ms`,
## `last_strength` and `pulses` let tests observe what the hardware would do.

const MS_PER_S := 1000.0

## A hold rumble is running (something lit during playback, or the CPU tile held).
var active: bool = false
## Length of the last pulse requested, in ms (0 when haptics are off).
var last_pulse_ms: int = 0
## Strength of the last pulse or hold requested.
var last_strength: float = 0.0
## Pulses requested so far.
var pulses: int = 0


func _ready() -> void:
	# One home for "every button pulses": hook every button that enters the tree.
	get_tree().node_added.connect(_on_node_added)
	# On a Steam Deck the input layer is invisible from outside; the log shows what Godot sees.
	Input.joy_connection_changed.connect(_log_joypads.unbind(2))
	_log_joypads()


## Light pulse on every input (tap, toggle, button).
func pulse() -> void:
	_pulse(Balance.get_int("haptics", "pulse_ms"), Balance.get_num("haptics", "pulse_strength"))


## Continuous rumble until stop_hold(); phones get one vibration at the start. `weak` is the
## decoy strength.
func start_hold(weak: bool = false) -> void:
	if active or not _enabled():
		return
	active = true
	last_strength = Balance.get_num("haptics", "decoy_strength" if weak else "hold_strength")
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(Balance.get_int("haptics", "pulse_ms"))
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, last_strength, 0.0, 0.0)


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


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		(node as BaseButton).pressed.connect(pulse)


func _enabled() -> bool:
	return GameState.settings.get("haptics", true)


func _log_joypads() -> void:
	var names: Array[String] = []
	for device: int in Input.get_connected_joypads():
		names.append("%d: %s" % [device, Input.get_joy_name(device)])
	print("Haptics: joypads [%s]" % ", ".join(names))


func _pulse(ms: int, strength: float) -> void:
	if not _enabled():
		return
	pulses += 1
	last_pulse_ms = ms
	last_strength = strength
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, strength, 0.0, ms / MS_PER_S)
