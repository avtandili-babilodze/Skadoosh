extends Node
## Player preferences (autoloaded as "Settings"), saved to user://settings.cfg.
##
## Owns the audio buses too: "Music" and "SFX" are created here at startup, so
## every other script can route sound to them by name without a bus layout file.

signal changed

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

## 0..1 slider positions; 0 mutes the bus.
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var fullscreen: bool = false
## Camera shake on hits and knock-outs.
var screen_shake: bool = true
## Lives each fighter starts a match with.
var stocks: int = 3
## How well the CPU plays in one-player matches: 0 easy, 1 normal, 2 hard.
var cpu_level: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_load()
	_fit_window_to_screen()
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F11:
		fullscreen = not fullscreen
		apply()
		save()


## The default window is sized for a 1080p display. On a smaller screen it
## would hang off the edges, so shrink it to fit and centre it.
func _fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var window := DisplayServer.window_get_size()
	if window.x <= screen.size.x * 0.96 and window.y <= screen.size.y * 0.96:
		return
	var shrink := minf(screen.size.x * 0.9 / window.x, screen.size.y * 0.9 / window.y)
	var fitted := Vector2i(Vector2(window) * shrink)
	DisplayServer.window_set_size(fitted)
	DisplayServer.window_set_position(screen.position + (screen.size - fitted) / 2)


## Pushes the current values into the engine (bus volumes, window mode).
func apply() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)
	if DisplayServer.get_name() != "headless":
		var wanted := (DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)
		if DisplayServer.window_get_mode() != wanted:
			DisplayServer.window_set_mode(wanted)
	changed.emit()


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", music_volume)
	file.set_value("audio", "sfx", sfx_volume)
	file.set_value("video", "fullscreen", fullscreen)
	file.set_value("video", "screen_shake", screen_shake)
	file.set_value("match", "stocks", stocks)
	file.set_value("match", "cpu_level", cpu_level)
	file.save(PATH)


func _load() -> void:
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return
	music_volume = clampf(file.get_value("audio", "music", music_volume), 0.0, 1.0)
	sfx_volume = clampf(file.get_value("audio", "sfx", sfx_volume), 0.0, 1.0)
	fullscreen = bool(file.get_value("video", "fullscreen", fullscreen))
	screen_shake = bool(file.get_value("video", "screen_shake", screen_shake))
	stocks = clampi(int(file.get_value("match", "stocks", stocks)), 1, 9)
	cpu_level = clampi(int(file.get_value("match", "cpu_level", cpu_level)), 0, 2)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


func _set_bus_volume(bus: StringName, slider: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, slider <= 0.001)
	# Squaring the slider gives an even-feeling loudness ramp.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, slider * slider)))
