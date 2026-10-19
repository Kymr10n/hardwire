extends Node
## Light haptic pulses on mobile. Respects GameState.settings.haptics.


## Light pulse; duration_ms < 0 uses haptics.pulse_ms from balance.json.
func pulse(duration_ms: int = -1) -> void:
	if not GameState.settings.get("haptics", true):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms if duration_ms >= 0 else Balance.get_int("haptics", "pulse_ms"))
