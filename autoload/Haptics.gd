extends Node
## Light haptic pulses on mobile. Respects GameState.settings.haptics.


func pulse(duration_ms: int = 20) -> void:
	if not GameState.settings.get("haptics", true):
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)
