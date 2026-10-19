extends Node
## Last-used input device, for on-screen glyphs (SPEC: Platforms and input > Glyphs).
## The only script that looks at raw key and joypad event classes; gameplay reads InputMap actions.

signal device_changed(device: Device)

enum Device { TOUCH, KEYBOARD_MOUSE, GAMEPAD }

## Xbox names (they match the Steam Deck) for the gamepad buttons the game binds.
const PAD_GLYPHS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View",
	JOY_BUTTON_START: "Menu",
}
const STICK_DEADZONE := 0.5

var device: Device = Device.TOUCH if OS.has_feature("mobile") else Device.KEYBOARD_MOUSE


func _input(event: InputEvent) -> void:
	var used: int = device_of(event)
	if used >= 0 and used != device:
		device = used as Device
		device_changed.emit(device)


## The device an event came from, or -1 if it says nothing (actions, emulated mouse, small moves).
## Touch emulated from the mouse counts as mouse; mouse emulated from touch is ignored.
static func device_of(event: InputEvent) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var emulated: bool = event.device == InputEvent.DEVICE_ID_EMULATION
		return Device.KEYBOARD_MOUSE if emulated else Device.TOUCH
	if event is InputEventMouseButton:
		return -1 if event.device == InputEvent.DEVICE_ID_EMULATION else Device.KEYBOARD_MOUSE
	if event is InputEventKey:
		return Device.KEYBOARD_MOUSE
	if event is InputEventJoypadButton:
		return Device.GAMEPAD
	if event is InputEventJoypadMotion and absf(event.axis_value) > STICK_DEADZONE:
		return Device.GAMEPAD
	return -1


## The key or button bound to `action` on the current device ("" on touch), from the InputMap.
func glyph(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if device == Device.GAMEPAD and event is InputEventJoypadButton:
			return PAD_GLYPHS.get(event.button_index, str(event.button_index))
		if device == Device.KEYBOARD_MOUSE and event is InputEventKey:
			var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
			return OS.get_keycode_string(code)
	return ""


## A prompt such as "Tap to begin", "Click or press Enter to begin" or "Press A to begin".
func prompt(action: StringName, verb: String) -> String:
	match device:
		Device.TOUCH:
			return "Tap to %s" % verb
		Device.GAMEPAD:
			return "Press %s to %s" % [glyph(action), verb]
	return "Click or press %s to %s" % [glyph(action), verb]


## True for any key, gamepad button, action, tap or click (SPEC: Boot "Press any button").
static func is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction:
		return event.is_pressed() and not event.is_echo()
	if event is InputEventScreenTouch:
		return not event.pressed
	return false
