extends Node
## Light haptic pulses on mobile. Respects GameState.settings.haptics.


## Light pulse on phones, short rumble on connected gamepads; duration_ms < 0 uses
## haptics.pulse_ms from balance.json.
func pulse(duration_ms: int = -1) -> void:
	if not GameState.settings.get("haptics", true):
		return
	var ms: int = duration_ms if duration_ms >= 0 else Balance.get_int("haptics", "pulse_ms")
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
	for device: int in Input.get_connected_joypads():
		Input.start_joy_vibration(device, Balance.get_num("haptics", "rumble_weak"),
			Balance.get_num("haptics", "rumble_strong"), ms / 1000.0)
