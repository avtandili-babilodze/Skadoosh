class_name FighterInput
extends RefCounted
## What a fighter is being told to do this physics tick. The default reads the
## player's keys and gamepad through the fighter's own action names; FighterBrain
## replaces poll() to play the fighter itself. The fighter only ever reads the
## fields below, so it cannot tell a person from the CPU.

## -1 (left) … 1 (right).
var axis: float = 0.0
## Held: fast-fall, and falling through platforms.
var down: bool = false
## Held: the heavy attack button. A dive lasts for as long as it is.
var heavy_held: bool = false
## Actions that went from up to down this tick: "jump", "dash", "attack",
## "attack2", "down".
var pressed: Dictionary = {}


func poll(fighter: Fighter, _delta: float) -> void:
	axis = Input.get_axis(fighter.action_left, fighter.action_right)
	down = Input.is_action_pressed(fighter.action_down)
	heavy_held = Input.is_action_pressed(fighter.action_attack)
	pressed = {
		"jump": Input.is_action_just_pressed(fighter.action_jump),
		"dash": Input.is_action_just_pressed(fighter.action_dash),
		"attack": Input.is_action_just_pressed(fighter.action_attack),
		"attack2": Input.is_action_just_pressed(fighter.action_attack2),
		"down": Input.is_action_just_pressed(fighter.action_down),
	}


func just(action: String) -> bool:
	return pressed.get(action, false)


## Forgets everything, as when control is taken away for a count-in.
func clear() -> void:
	axis = 0.0
	down = false
	heavy_held = false
	pressed = {}
