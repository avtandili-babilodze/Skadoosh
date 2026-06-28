extends Node
## Global input registrar (autoloaded as "GameInput").
##
## Runs ONCE at game startup and guarantees every control action exists in the
## InputMap, no matter what's in Project Settings. This is the single source of
## truth for keybindings — individual players just reference the action names.
##
## To rebind a key, change it here. To support gamepads later, add the joypad
## events in this same place.

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


func _ready() -> void:
	# Force a clean window title (otherwise debug runs show "Skadoosh (DEBUG)").
	get_window().title = "Skadoosh"

	for action: StringName in BINDINGS:
		# Start each action clean so this file is authoritative.
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action)

		var event := InputEventKey.new()
		event.physical_keycode = BINDINGS[action]
		InputMap.action_add_event(action, event)
