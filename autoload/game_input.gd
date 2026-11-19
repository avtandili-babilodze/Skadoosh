extends Node
## Global input registrar (autoloaded as "GameInput").
##
## Runs ONCE at game startup and guarantees every control action exists in the
## InputMap, no matter what's in Project Settings. This is the single source of
## truth for keybindings — individual players just reference the action names.
##
## To rebind a key, change it here. Gamepads are bound here too: the first pad
## drives Player 1 and the second drives Player 2, alongside the keyboard.

## action name -> physical key. Physical keycodes are layout-independent
## (so "A" is the same physical key on QWERTY/AZERTY/etc.).
const BINDINGS := {
	# Player 1 — left hand (WASD)
	"p1_left": KEY_A,
	"p1_right": KEY_D,
	"p1_jump": KEY_W,
	"p1_down": KEY_S,
	"p1_dash": KEY_SHIFT,
	"p1_attack": KEY_F,
	"p1_attack2": KEY_G,
	# Player 2 — right hand (arrow keys)
	"p2_left": KEY_LEFT,
	"p2_right": KEY_RIGHT,
	"p2_jump": KEY_UP,
	"p2_down": KEY_DOWN,
	"p2_dash": KEY_CTRL,
	"p2_attack": KEY_SLASH,
	"p2_attack2": KEY_APOSTROPHE,
}

## action suffix -> gamepad buttons, applied to pad 0 (p1_) and pad 1 (p2_).
const PAD_BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT],
	"right": [JOY_BUTTON_DPAD_RIGHT],
	"jump": [JOY_BUTTON_A, JOY_BUTTON_DPAD_UP],
	"down": [JOY_BUTTON_DPAD_DOWN],
	"dash": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER],
	"attack": [JOY_BUTTON_B, JOY_BUTTON_Y],
	"attack2": [JOY_BUTTON_X],
}

## action suffix -> [axis, direction] for the left stick.
const PAD_AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0],
	"right": [JOY_AXIS_LEFT_X, 1.0],
	"down": [JOY_AXIS_LEFT_Y, 1.0],
}

## Extra keys for the built-in menu actions, so either player can drive a menu
## with the hand that is already on the keyboard.
const MENU_KEYS := {
	"ui_up": [KEY_W],
	"ui_down": [KEY_S],
	"ui_left": [KEY_A],
	"ui_right": [KEY_D],
	"ui_accept": [KEY_F, KEY_SLASH],
	"ui_cancel": [KEY_BACKSPACE],
}

## Keyboard and gamepad buttons that pause a match.
const PAUSE_ACTION := &"pause"


func _ready() -> void:
	# Force a clean window title (otherwise debug runs show "Skadoosh (DEBUG)").
	get_window().title = "Skadoosh"

	for action: StringName in BINDINGS:
		# Start each action clean so this file is authoritative.
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, 0.4)

		var event := InputEventKey.new()
		event.physical_keycode = BINDINGS[action]
		InputMap.action_add_event(action, event)

	for player in 2:
		var prefix := "p%d_" % (player + 1)
		for suffix: String in PAD_BUTTONS:
			for button: int in PAD_BUTTONS[suffix]:
				var press := InputEventJoypadButton.new()
				press.device = player
				press.button_index = button
				InputMap.action_add_event(prefix + suffix, press)
		for suffix: String in PAD_AXES:
			var motion := InputEventJoypadMotion.new()
			motion.device = player
			motion.axis = PAD_AXES[suffix][0]
			motion.axis_value = PAD_AXES[suffix][1]
			InputMap.action_add_event(prefix + suffix, motion)

	for action: StringName in MENU_KEYS:
		for key: int in MENU_KEYS[action]:
			var menu_key := InputEventKey.new()
			menu_key.physical_keycode = key
			InputMap.action_add_event(action, menu_key)

	if not InputMap.has_action(PAUSE_ACTION):
		InputMap.add_action(PAUSE_ACTION)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event(PAUSE_ACTION, escape)
	var start := InputEventJoypadButton.new()
	start.device = -1
	start.button_index = JOY_BUTTON_START
	InputMap.action_add_event(PAUSE_ACTION, start)


## The readable key name for an action, for on-screen control hints.
func key_label(action: StringName) -> String:
	if not BINDINGS.has(action):
		return "?"
	match BINDINGS[action]:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_SLASH: return "/"
		KEY_APOSTROPHE: return "'"
	return OS.get_keycode_string(BINDINGS[action])
